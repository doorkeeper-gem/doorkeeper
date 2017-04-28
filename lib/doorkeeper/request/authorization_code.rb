require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class AuthorizationCode < Strategy
      delegate :client, :parameters, to: :server

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.configuration,
          grant,
          client,
          parameters
        )
      end

      private

      def grant
        AccessGrant.by_token(parameters[:code])
        Doorkeeper.configuration
      end
    end
  end
end
