# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::Config::Option do
  class Extension
    def self.configure(&block)
      @config = Config::Builder.new(Config.new, &block).build
    end

    def self.configuration
      @config || (raise Errors::MissingConfiguration)
    end

    class Config
      class Builder < Doorkeeper::Config::AbstractBuilder
        def enforce_something
          @config.instance_variable_set(:@enforce_something, true)
        end
      end

      def enforce_something?
        if defined?(@enforce_something)
          @enforce_something
        else
          false
        end
      end

      def self.builder_class
        Config::Builder
      end

      extend Doorkeeper::Config::Option
    end
  end

  it "allows to define custom options in extensions" do
    expect do
      Extension::Config.option(:some_option, default: 1)
    end.not_to raise_error

    Extension.configure do
      some_option 20
      enforce_something
    end

    expect(Extension.configuration.some_option).to eq(20)
    expect(Extension.configuration.enforce_something?).to be(true)
  end

  describe "option definition edge cases" do
    let(:config_class) do
      builder = Class.new(Doorkeeper::Config::AbstractBuilder)

      Class.new do
        @builder_class = builder

        class << self
          attr_reader :builder_class
        end

        extend Doorkeeper::Config::Option
      end
    end

    def configure(config_class, &block)
      config_class.builder_class.new(config_class.new, &block).config
    end

    it "warns when an option is defined twice and keeps the last definition" do
      config_class.option(:some_option, default: 1)

      expect(Kernel).to receive(:warn).with(
        /\[DOORKEEPER\] Option some_option already defined and will be overridden/,
      )
      config_class.option(:some_option, default: 2)

      expect(config_class.new.some_option).to eq(2)
    end

    it "warns when a deprecated option is set" do
      config_class.option(:legacy_option, deprecated: true)

      expect(Kernel).to receive(:warn).with(
        /\[DOORKEEPER\] legacy_option has been deprecated and will soon be removed/,
      )

      config = configure(config_class) { legacy_option 42 }

      expect(config.legacy_option).to eq(42)
    end

    it "appends the custom message when an option is deprecated with a message" do
      config_class.option(:legacy_option, deprecated: { message: "Use new_option instead" })

      expect(Kernel).to receive(:warn).with(
        /legacy_option has been deprecated.*\nUse new_option instead/,
      )

      configure(config_class) { legacy_option 42 }
    end

    it "builds the option value with a custom builder class" do
      value_builder = Class.new do
        def initialize
          @value = yield
        end

        def build
          { built: @value }
        end
      end
      config_class.option(:built_option, builder_class: value_builder)

      config = configure(config_class) { built_option { 42 } }

      expect(config.built_option).to eq(built: 42)
    end
  end
end
