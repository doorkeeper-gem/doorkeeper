module Doorkeeper
  module OAuth
    module Authorization
      class Token
        attr_accessor :pre_auth, :resource_owner, :token

        def initialize(pre_auth, resource_owner)
          @pre_auth = pre_auth
          @resource_owner = resource_owner
        end

        def self.access_token_expires_in(server, pre_auth_or_oauth_client)
          if expiration = custom_expiration(server, pre_auth_or_oauth_client)
            expiration
          else
            server.access_token_expires_in
          end
        end

        def issue_token
          resource_owner_obj = nil
          if resource_owner.is_a? Integer
            r_owner_accessor = Doorkeeper.configuration.resource_owner_accessor.constantize
            resource_owner_obj = r_owner_accessor.get_by_id(resource_owner)
          else
            resource_owner_obj = resource_owner
          end
          @token ||= AccessToken.find_or_create_for(
            pre_auth.client,
            resource_owner_obj,
            pre_auth.scopes,
            self.class.access_token_expires_in(configuration, pre_auth),
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

        private

        def self.custom_expiration(server, pre_auth_or_oauth_client)
          oauth_client = if pre_auth_or_oauth_client.respond_to?(:client)
                           pre_auth_or_oauth_client.client
                         else
                           pre_auth_or_oauth_client
                         end

          server.custom_access_token_expires_in.call(oauth_client)
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
