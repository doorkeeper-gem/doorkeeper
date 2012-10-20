module Doorkeeper
  module Request
    class AuthorizationCode
      def self.build(server)
        new(server.client, server)
      end

      attr_accessor :client, :server

      def initialize(client, server)
        @client, @server = client, server
      end

      def request
        @request ||= OAuth::AccessTokenRequest.new(client, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
