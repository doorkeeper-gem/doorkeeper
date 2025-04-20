# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class Mechanism
      attr_reader :name, :mechanism

      def initialize(name, **options)
        @name = name
        @mechanism = options[:mechanism]
        @authenticates_client = options.key?(:authenticates_client) ? options[:authenticates_client] : true
      end

      def authenticates_client?
        !!@authenticates_client
      end

      def matches_request?(request)
        @mechanism.matches_request?(request)
      end
    end
  end
end
