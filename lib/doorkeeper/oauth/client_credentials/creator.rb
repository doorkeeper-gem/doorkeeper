module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      class Creator
        def call(client, scopes, attributes = {})
          existing_token = existing_token_for(client, scopes)
          if existing_token
            return existing_token if existing_token.accessible?
            existing_token.revoke
          end
          create(client, scopes, attributes)
        end

      private

        def existing_token_for(client, scopes)
          Doorkeeper::AccessToken.matching_token_for client, nil, scopes
        end

        def create(client, scopes, attributes = {})
          token = Doorkeeper::AccessToken.new
          token.application_id = client.id
          token.scopes = scopes.to_s
          token.use_refresh_token = attributes[:use_refresh_token] if attributes[:use_refresh_token]
          token.expires_in = attributes[:expires_in] if attributes[:expires_in]
          token.save!
          token
        end
      end
    end
  end
end
