# frozen_string_literal: true

module Doorkeeper
  module Request
    class ClientCredentials < Strategy
      delegate :client, :dpop_proof, :parameters, to: :server

      def request
        @request ||= OAuth::ClientCredentialsRequest.new(
          Doorkeeper.config,
          client,
          parameters,
        ).tap { |request| request.dpop_proof = dpop_proof }
      end
    end
  end
end
