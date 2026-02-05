require 'active_support/all'
require 'rails/generators/test_case'
require 'generator_spec/matcher'

module GeneratorSpec
  module TestCase
    extend ActiveSupport::Concern
    include Matcher
    include FileUtils

    included do
      cattr_accessor :test_case, :test_case_instance

      self.test_case = Class.new(Rails::Generators::TestCase) do
        def fake_test_case; end
        def add_assertion; end
      end
      self.test_case_instance = self.test_case.new(:fake_test_case)
      self.test_case.tests described_class
    end

    module ClassMethods
      def tests(klass)
        self.test_case.generator_class = klass
      end

      def arguments(array)
        self.test_case.default_arguments = array
      end

      def destination(path)
        self.test_case.destination_root = path
      end
    end

    def method_missing(method_sym, *arguments, &block)
      self.test_case_instance.send(method_sym, *arguments, &block)
    end

    def respond_to?(method_sym, include_private = false)
      if self.test_case_instance.respond_to?(method_sym)
        true
      else
        super
      end
    end
  end
end
