module Doorkeeper
  module Request
    class Password
      def self.build(server)
        new(server.client, server.resource_owner, server)
      end

      attr_accessor :client, :resource_owner, :server

      def initialize(client, resource_owner, server)
        @client, @resource_owner, @server = client, resource_owner, server
      end

      def request
        @request ||= OAuth::PasswordAccessTokenRequest.new(Doorkeeper.configuration, client, resource_owner, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
