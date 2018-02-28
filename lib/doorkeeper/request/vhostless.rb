require 'doorkeeper/request/strategy'

module Doorkeeper
  module Request
    class Vhostless < Strategy
      delegate :credentials, :resource_owners, :parameters, to: :server

      def request
        @request ||= OAuth::VhostlessAccessTokenRequest.new(
          Doorkeeper.configuration,
          client,
          resource_owners,
          parameters
        )
      end

      private

      def client
        if credentials
          server.client
        elsif parameters[:client_id]
          server.client_via_uid
        end
      end
    end
  end
end
