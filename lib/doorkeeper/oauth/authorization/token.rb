module Doorkeeper
  module OAuth
    module Authorization
      class Token
        attr_accessor :pre_auth, :resource_owner, :token

        def initialize(pre_auth, resource_owner)
          @pre_auth       = pre_auth
          @resource_owner = resource_owner
        end

        def issue_token
          @token ||= AccessToken.create!(
            application_id: pre_auth.client.id,
            resource_owner_id: resource_owner.id,
            scopes: pre_auth.scopes.to_s,
            expires_in: configuration.access_token_expires_in,
            use_refresh_token: false
          )
        end

        def native_redirect
          {
            controller: 'doorkeeper/token_info',
            action: :show,
            access_token: token.token
          }
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
