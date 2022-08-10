# frozen_string_literal: true

require 'open3'

require 'spec_helper'
require 'active_support'
require 'active_support/core_ext'

def testing_ruby_2?
  RUBY_VERSION.split('.')[0].to_i == 2
end

class TestRailsApp
  def initialize(fixture_dir)
    @fixture_dir = fixture_dir
  end

  attr_reader :fixture_dir

  def run_cmd(cmd, env = {})
    run_process method(:system), cmd, env
  end

  def spawn_cmd(cmd, env = {})
    puts "Spawning `#{cmd}` in #{fixture_dir}..."
    run_process Process.method(:spawn), cmd, env
  end

  def capture_cmd(cmd, env = {})
    puts "Capturing `#{cmd}` in #{fixture_dir}..."
    run_process(Open3.method(:capture2), cmd, env).first
  end

  def database_name
    # This is used locally too, so make the name nice and unique.
    @database_name ||= "appland-rails-test-#{Random.new.bytes(8).unpack1('h*')}"
  end

  def bundle
    return if @bundled

    run_cmd 'bundle'
    @bundled = true
  end

  def prepare_db
    return if @db_prepared

    bundle
    run_cmd './bin/rake db:create db:schema:load'
    @db_prepared = true
    at_exit { drop_db }
  end

  def drop_db
    return unless @db_prepared

    run_cmd './bin/rake db:drop'
    @db_prepared = false
  end

  def tmpdir
    @tmpdir ||= File.join(fixture_dir, 'tmp')
  end

  def run_specs
    return if @specs_ran or use_existing_data?

    prepare_db
    FileUtils.rm_rf tmpdir
    run_cmd \
      './bin/rspec spec/controllers/users_controller_spec.rb spec/controllers/users_controller_api_spec.rb',
      'APPMAP' => 'true'
    @specs_ran = true
  end

  def self.for_fixture(fixture_dir)
    @apps ||= {}
    @apps[fixture_dir] ||= TestRailsApp.new fixture_dir
  end

  protected

  def run_process(method, cmd, env, options = {})
    Bundler.with_clean_env do
      method.call \
        env.merge('TEST_DATABASE' => database_name),
        cmd,
        options.merge(chdir: fixture_dir)
    end
  end
end

shared_context 'Rails app pg database' do |dir|
  before(:all) { @app = TestRailsApp.for_fixture dir }
  let(:app) { @app }
end

shared_context 'rails integration test setup' do
  let(:tmpdir) { app.tmpdir }
  before(:all) { @app.run_specs } unless use_existing_data?

  let(:appmap_json_path) { File.join(tmpdir, 'appmap/rspec', appmap_json_file) }
  let(:appmap) { JSON.parse File.read(appmap_json_path) }
  let(:events) { appmap['events'] }
end
