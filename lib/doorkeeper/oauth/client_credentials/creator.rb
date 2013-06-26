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
          Doorkeeper::AccessToken.create(attributes.merge({
            :application_id => client.id,
            :scopes         => scopes.to_s
          }))
        end
      end
    end
  end
end
