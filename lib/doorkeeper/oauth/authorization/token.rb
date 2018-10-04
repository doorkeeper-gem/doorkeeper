# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Authorization
      class Token
        attr_accessor :pre_auth, :resource_owner, :token

        class << self
          def build_context(pre_auth_or_oauth_client, grant_type, scopes)
            oauth_client = if pre_auth_or_oauth_client.respond_to?(:client)
                             pre_auth_or_oauth_client.client
                           else
                             pre_auth_or_oauth_client
                           end

            Doorkeeper::OAuth::Authorization::Context.new(
              oauth_client,
              grant_type,
              scopes
            )
          end

          def access_token_expires_in(server, context)
            if (expiration = server.custom_access_token_expires_in.call(context))
              expiration
            else
              server.access_token_expires_in
            end
          end

          def refresh_token_enabled?(server, context)
            if server.refresh_token_enabled?.respond_to? :call
              server.refresh_token_enabled?.call(context)
            else
              !!server.refresh_token_enabled?
            end
          end
        end

        def initialize(pre_auth, resource_owner)
          @pre_auth       = pre_auth
          @resource_owner = resource_owner
        end

        def issue_token
          context = self.class.build_context(
            pre_auth.client,
            Doorkeeper::OAuth::IMPLICIT,
            pre_auth.scopes
          )
          @token ||= AccessToken.find_or_create_for(
            pre_auth.client,
            resource_owner.id,
            pre_auth.scopes,
            self.class.access_token_expires_in(configuration, context),
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
