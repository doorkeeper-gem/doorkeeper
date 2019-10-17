# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest < BaseRequest
      class Creator
        def call(client, scopes, attributes = {})
          existing_token = existing_token_for(client, scopes) if needs_existing_token?

          return existing_token if config.reuse_access_token && existing_token&.reusable?

          existing_token&.revoke if config.revoke_previous_client_credentials_token

          Doorkeeper.config.access_token_model.find_or_create_for(
            client, nil, scopes, attributes[:expires_in],
            attributes[:use_refresh_token]
          )
        end

        private

        def needs_existing_token?
          config.reuse_access_token || config.revoke_previous_client_credentials_token
        end

        def existing_token_for(client, scopes)
          Doorkeeper.config.access_token_model.matching_token_for client, nil, scopes
        end

        def config
          Doorkeeper.configuration
        end
      end
    end
  end
end
