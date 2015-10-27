module Doorkeeper
  module Request
    class RefreshToken
      attr_accessor :refresh_token, :credentials, :server

      def initialize(server)
        @refresh_token = server.current_refresh_token
        @credentials = server.credentials
        @server = server
      end

      def request
        @request ||= OAuth::RefreshTokenRequest.new(Doorkeeper.configuration, refresh_token, credentials, server.parameters)
      end

      def authorize
        request.authorize
      end
    end
  end
end
