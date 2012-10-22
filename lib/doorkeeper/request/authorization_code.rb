module Doorkeeper
  module Request
    class AuthorizationCode
      def self.build(server)
        new(server.grant, server.client, server)
      end

      attr_accessor :grant, :client, :server

      def initialize(grant, client, server)
        @grant, @client, @server = grant, client, server
      end

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(Doorkeeper.configuration, grant, client, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
