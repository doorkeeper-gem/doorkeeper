# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3.1 "client_secret_post": client credentials are sent in
      # the request body. The query string is intentionally ignored so that
      # credentials must be supplied in the body as the spec requires.
      class ClientSecretPost
        def self.matches_request?(request)
          params = request.request_parameters.with_indifferent_access

          request.post? &&
            params[:client_id].present? &&
            params[:client_secret].present?
        end

        def self.authenticate(request)
          params = request.request_parameters.with_indifferent_access

          Doorkeeper::ClientAuthentication::Credentials.new(
            params[:client_id],
            params[:client_secret],
          )
        end
      end
    end
  end
end
