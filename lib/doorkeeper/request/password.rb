require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class Password < Strategy
      delegate :credentials, :resource_owner, :parameters, to: :server

      def request
        @request ||= OAuth::PasswordAccessTokenRequest.new(Doorkeeper.configuration, credentials, resource_owner, parameters)
      end
    end
  end
end
