module Doorkeeper
  module Request
    class AuthorizationCode
      attr_accessor :grant, :client, :server

      def initialize(server)
        @grant, @client, @server = server.grant, server.client, server
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
