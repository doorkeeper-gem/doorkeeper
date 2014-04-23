module Doorkeeper
  module Request
    class Assertion
      def self.build(server)
        new(server.credentials, server.resource_owner_from_assertion, server)
      end

      attr_accessor :credentials, :resource_owner, :server

      def initialize(credentials, resource_owner, server)
        @credentials, @resource_owner, @server = credentials, resource_owner, server
      end

      def request
        # TODO: For now OAuth::PasswordAccessTokenRequest is reused for the Assertion Flow. In need of
        # OAuth::AssertionAccessTokenRequest in future
        @request ||= OAuth::PasswordAccessTokenRequest.new(Doorkeeper.configuration, credentials, resource_owner, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
