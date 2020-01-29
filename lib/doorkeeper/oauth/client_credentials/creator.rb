# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest < BaseRequest
      class Creator
        def call(client, scopes, attributes = {})
          existing_token = existing_token_for(client, scopes)

          return existing_token if Doorkeeper.config.reuse_access_token && existing_token&.reusable?

          existing_token&.revoke

          Doorkeeper.config.access_token_model.find_or_create_for(
            client, nil, scopes, attributes[:expires_in],
            attributes[:use_refresh_token],
          )
        end

        private

        def existing_token_for(client, scopes)
          Doorkeeper.config.access_token_model.matching_token_for(client, nil, scopes)
        end
      end
    end
  end
end
