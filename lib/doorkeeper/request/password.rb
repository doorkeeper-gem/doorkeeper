# frozen_string_literal: true

module Doorkeeper
  module Request
    class Password < Strategy
      delegate :credentials, :resource_owner, :dpop_proof, :parameters, :client, to: :server

      def request
        @request ||= OAuth::PasswordAccessTokenRequest.new(
          Doorkeeper.config,
          client,
          credentials,
          resource_owner,
          dpop_proof:,
          parameters:,
        )
      end
    end
  end
end
