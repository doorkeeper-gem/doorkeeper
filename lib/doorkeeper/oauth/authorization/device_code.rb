module Doorkeeper
  module OAuth
    module Authorization
      class DeviceCode
        attr_accessor :pre_auth, :token

        def initialize(pre_auth)
          @pre_auth = pre_auth
        end

        def issue_token
          @token ||= DeviceAccessGrant.create!(
            application_id: pre_auth.client.id,
            expires_in: configuration.authorization_code_expires_in,
            scopes: pre_auth.scopes.to_s
          )
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
