require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class AuthorizationCode < Strategy
      delegate :grant, :client, :parameters, to: :server

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(Doorkeeper.configuration, grant, client, parameters)
      end
    end
  end
end
