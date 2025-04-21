# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class Method
      attr_reader :name, :method

      def initialize(name, **options)
        @name = name
        @method = options[:method]
      end

      def matches_request?(request)
        @method.matches_request?(request)
      end
    end
  end
end
