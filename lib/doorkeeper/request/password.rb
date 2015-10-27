require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class Password < Strategy
      attr_accessor :credentials, :resource_owner

      def initialize(server)
        super
        @credentials = server.credentials
        @resource_owner = server.resource_owner
      end

      def request
        @request ||= OAuth::PasswordAccessTokenRequest.new(Doorkeeper.configuration, credentials, resource_owner, server.parameters)
      end
    end
  end
end
