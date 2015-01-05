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
          @token ||= AccessToken.find_or_create_for(
              pre_auth.client,
              resource_owner.id,
              pre_auth.scopes,
              configuration.access_token_expires_in,
              false
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
