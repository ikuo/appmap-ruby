# frozen_string_literal: true

# rubocop:disable Security/Eval, Style/EvalWithLocation

require 'spec_helper'
require 'appmap/config'

describe 'AppMap::Handler::Eval' do
  include_context 'collect events'
  let!(:config) { AppMap::Config.new('hook_spec') }
  before { AppMap.configuration = config }
  after { AppMap.configuration = nil }

  def record_block
    AppMap::Hook.new(config).enable do
      tracer = AppMap.tracing.trace
      AppMap::Event.reset_id_counter
      begin
        yield
      ensure
        AppMap.tracing.delete(tracer)
      end
      tracer
    end
  end

  it 'produces a simple result' do
    tracer = record_block do
      expect(eval('12')).to eq(12)
    end
    events = collect_events(tracer)
    expect(events[0]).to match hash_including \
      defined_class: 'Kernel',
      method_id: 'eval',
      parameters: [{ class: 'Array', kind: :rest, name: 'arg', value: '[12]' }]
  end

  # a la Ruby 2.6.3 ruby-token.rb
  # token_c = eval("class #{token_n} < #{super_token}; end; #{token_n}")
  it 'can define a new class' do
    num = (Random.random_number * 10_000).to_i
    class_name = "Cls_#{num}"
    m = ClassMaker
    cls = nil
    record_block do
      cls = m.make_class class_name
    end
    expect(cls).to be_instance_of(Class)
    # If execution context wasn't substituted, the class would be defined as
    # eg. AppMap::Handler::Eval::Cls_7566
    expect { AppMap::Handler::Eval.const_get(class_name) }.to raise_error(NameError)
    # This would be the right behavior
    expect(m.const_get(class_name)).to be_instance_of(Class)
    expect(m.const_get(class_name)).to eq(cls)
    new_cls = Class.new do
      include m
    end
    expect(new_cls.const_get(class_name)).to eq(cls)
  end
end

module ClassMaker
  def self.make_class(class_name)
    eval "class #{class_name}; end; #{class_name}"
  end
end
