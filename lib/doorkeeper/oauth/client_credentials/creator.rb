# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest < BaseRequest
      class Creator
        def call(client, scopes, attributes = {})
          if lookup_existing_token?
            existing_token = find_existing_token_for(client, scopes)
            return existing_token if server_config.reuse_access_token && existing_token&.reusable?

            existing_token&.revoke if server_config.revoke_previous_client_credentials_token
          end

          server_config.access_token_model.find_or_create_for(
            client, nil, scopes, attributes[:expires_in],
            attributes[:use_refresh_token],
          )
        end

        private

        def lookup_existing_token?
          server_config.reuse_access_token || server_config.revoke_previous_client_credentials_token
        end

        def find_existing_token_for(client, scopes)
          server_config.access_token_model.matching_token_for(client, nil, scopes)
        end

        def server_config
          Doorkeeper.config
        end
      end
    end
  end
end
