# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Authorization
      class Code
        attr_accessor :pre_auth, :resource_owner, :token

        def initialize(pre_auth, resource_owner)
          @pre_auth = pre_auth
          @resource_owner = resource_owner
        end

        def issue_token
          @token ||= AccessGrant.create!(access_grant_attributes)
        end

        def oob_redirect
          { action: :show, code: token.plaintext_token }
        end

        def configuration
          Doorkeeper.configuration
        end

        private

        def authorization_code_expires_in
          configuration.authorization_code_expires_in
        end

        def access_grant_attributes
          pkce_attributes.merge(
            application_id: pre_auth.client.id,
            resource_owner_id: resource_owner.id,
            expires_in: authorization_code_expires_in,
            redirect_uri: pre_auth.redirect_uri,
            scopes: pre_auth.scopes.to_s
          )
        end

        def pkce_attributes
          return {} unless pkce_supported?

          {
            code_challenge: pre_auth.code_challenge,
            code_challenge_method: pre_auth.code_challenge_method,
          }
        end

        # Ensures firstly, if migration with additional PKCE columns was
        # generated and migrated
        def pkce_supported?
          Doorkeeper::AccessGrant.pkce_supported?
        end
      end
    end
  end
end
