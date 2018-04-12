module Doorkeeper
  module OAuth
    module Authorization
      class Token
        attr_accessor :pre_auth, :resource_owner, :token

        class << self
          def access_token_expires_in(server, pre_auth_or_oauth_client, grant_type)
            if (expiration = custom_expiration(server, pre_auth_or_oauth_client, grant_type))
              expiration
            else
              server.access_token_expires_in
            end
          end

          private

          def custom_expiration(server, pre_auth_or_oauth_client, grant_type)
            oauth_client = if pre_auth_or_oauth_client.respond_to?(:client)
                             pre_auth_or_oauth_client.client
                           else
                             pre_auth_or_oauth_client
                           end

            server.custom_access_token_expires_in.call(oauth_client, grant_type)
          end
        end

        def initialize(pre_auth, resource_owner)
          @pre_auth       = pre_auth
          @resource_owner = resource_owner
        end

        def issue_token
          @token ||= AccessToken.find_or_create_for(
            pre_auth.client,
            resource_owner.id,
            pre_auth.scopes,
            self.class.access_token_expires_in(
              configuration,
              pre_auth,
              Doorkeeper::OAuth::IMPLICIT
            ),
            false
          )
        end

        def native_redirect
          {
            controller: controller,
            action: :show,
            access_token: token.token
          }
        end

        private

        def configuration
          Doorkeeper.configuration
        end

        def controller
          @controller ||= begin
            mapping = Doorkeeper::Rails::Routes.mapping[:token_info] || {}
            mapping[:controllers] || 'doorkeeper/token_info'
          end
        end
      end
    end
  end
end
