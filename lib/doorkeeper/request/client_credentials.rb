# frozen_string_literal: true

module Doorkeeper
  module Request
    class ClientCredentials < Strategy
      delegate :client, :dpop_proof, :parameters, to: :server

      def request
        @request ||= OAuth::ClientCredentialsRequest.new(
          Doorkeeper.config,
          client,
          dpop_proof:,
          parameters:,
        )
      end
    end
  end
end
