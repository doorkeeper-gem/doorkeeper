module Doorkeeper
  module Request
    class RefreshToken
      def self.build(server)
        new(server.current_refresh_token, server.credentials, server)
      end

      attr_accessor :refresh_token, :credentials, :server

      def initialize(refresh_token, credentials, server)
        @refresh_token, @credentials, @server = refresh_token, credentials, server
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
