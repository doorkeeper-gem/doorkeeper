require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class RefreshToken < Strategy
      attr_accessor :refresh_token, :credentials

      def initialize(server)
        super
        @refresh_token = server.current_refresh_token
        @credentials = server.credentials
      end

      def request
        @request ||= OAuth::RefreshTokenRequest.new(Doorkeeper.configuration, refresh_token, credentials, server.parameters)
      end
    end
  end
end
