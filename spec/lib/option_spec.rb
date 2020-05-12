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
end
