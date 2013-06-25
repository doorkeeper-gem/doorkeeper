module Doorkeeper
  module Request
    class Assertion
      def self.build(server)
        new(server.client, server.resource_owner_from_assertion, server)
      end

      attr_accessor :client, :resource_owner, :server

      def initialize(client, resource_owner, server)
        @client, @resource_owner, @server = client, resource_owner, server
      end

      def request
        # TODO: For now OAuth::PasswordAccessTokenRequest is reused for the Assertion Flow. In need of
        # OAuth::AssertionAccessTokenRequest in future
        @request ||= OAuth::PasswordAccessTokenRequest.new(Doorkeeper.configuration, client, resource_owner, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
