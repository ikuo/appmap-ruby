#!/usr/bin/env ruby
# frozen_string_literal: true

require 'test_helper'
require 'English'

class MinitestTest < Minitest::Test
  def perform_minitest_test(test_name)
    Bundler.with_clean_env do
      Dir.chdir 'test/fixtures/minitest_recorder' do
        system 'bundle config --local local.appmap ../../..'
        system 'bundle'
        system({ 'APPMAP_RECORD_MINITEST' => 'true' }, %(bundle exec ruby -Ilib -Itest test/#{test_name}_test.rb))

        yield
      end
    end
  end

  def test_succeeded
    perform_minitest_test 'hello' do
      appmap_file = 'tmp/appmap/minitest/Hello_hello.appmap.json'

      assert File.file?(appmap_file), 'appmap output file does not exist'
      appmap = JSON.parse(File.read(appmap_file))
      assert_equal AppMap::APPMAP_FORMAT_VERSION, appmap['version']
      assert_includes appmap.keys, 'metadata'
      metadata = appmap['metadata']
      assert_equal 'minitest_recorder', metadata['app']
      assert_equal 'minitest', metadata['recorder']['name']
      assert_equal 'tests', metadata['recorder']['type']
      assert_equal 'ruby', metadata['language']['name']
      assert_equal 'Hello hello', metadata['name']
      assert_equal 'succeeded', metadata['test_status']
      assert_equal 'test/hello_test.rb:9', metadata['source_location']
    end
  end

  def test_failed
    perform_minitest_test 'hello_failed' do
      appmap_file = 'tmp/appmap/minitest/Hello_failed_failed.appmap.json'

      assert File.file?(appmap_file), 'appmap output file does not exist'
      appmap = JSON.parse(File.read(appmap_file))
      metadata = appmap['metadata']
      assert_equal 'failed', metadata['test_status']
      test_failure = metadata['test_failure']
      assert_equal test_failure['message'].strip, <<~MESSAGE.strip
      Expected: \"Bye!\"\n  Actual: \"Hello!\"
      MESSAGE
      assert_equal test_failure['location'], 'test/hello_failed_test.rb:10'
    end
  end
end
