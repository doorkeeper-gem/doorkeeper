module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      class Creator
        def call(client, scopes, attributes = {})
          AccessToken.create(attributes.merge(
            application_id: client.id,
            scopes: scopes.to_s
          ))
        end
      end
    end
  end
end
