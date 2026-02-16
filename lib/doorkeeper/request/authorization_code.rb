# frozen_string_literal: true

module Doorkeeper
  module Request
    class AuthorizationCode < Strategy
      delegate :client, :dpop_proof, :parameters, to: :server

      def request
        @request ||= OAuth::AuthorizationCodeRequest.new(
          Doorkeeper.config,
          grant,
          client,
          dpop_proof:,
          parameters:,
        )
      end

      private

      def grant
        raise Errors::MissingRequiredParameter, :code if parameters[:code].blank?

        Doorkeeper.config.access_grant_model.by_token(parameters[:code])
      end
    end
  end
end
