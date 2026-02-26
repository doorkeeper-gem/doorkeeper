# frozen_string_literal: true

module Doorkeeper
  module Request
    class RefreshToken < Strategy
      delegate :credentials, :dpop_proof, :parameters, to: :server

      def refresh_token
        Doorkeeper.config.access_token_model.by_refresh_token(parameters[:refresh_token])
      end

      def request
        @request ||= OAuth::RefreshTokenRequest.new(
          Doorkeeper.config,
          refresh_token,
          credentials,
          dpop_proof:,
          parameters:,
        )
      end
    end
  end
end
