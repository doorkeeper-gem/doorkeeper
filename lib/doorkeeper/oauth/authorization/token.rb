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
          @token = Doorkeeper::AccessToken.new
          @token.application_id = pre_auth.client.id
          @token.resource_owner_id = resource_owner.id
          @token.scopes = pre_auth.scopes.to_s
          @token.expires_in = configuration.access_token_expires_in
          @token.use_refresh_token = false
          @token.save!
          @token
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
