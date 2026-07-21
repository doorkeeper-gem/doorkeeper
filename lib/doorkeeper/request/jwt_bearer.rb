# frozen_string_literal: true

module Doorkeeper
  module Request
    # Strategy for the jwt-bearer grant (urn:ietf:params:oauth:grant-type:jwt-bearer, ID-JAG).
    class JwtBearer < Strategy
      delegate :client, :parameters, to: :server

      def request
        @request ||= OAuth::JwtBearerAccessTokenRequest.new(
          Doorkeeper.config,
          client,
          parameters[:assertion],
          parameters,
        )
      end
    end
  end
end
