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
    end
  end
end
