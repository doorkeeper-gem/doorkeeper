module Doorkeeper
  module OAuth
    module Helpers
      module FindOrCreateAccessToken
        def self.for(application, resource_owner_id, scopes, expires_in, use_refresh_token)
          if Doorkeeper.configuration.reuse_access_token
            token = Doorkeeper::AccessToken.send :last_authorized_token_for, application, resource_owner_id
            access_token = Doorkeeper::AccessToken.matching_token_for(application, resource_owner_id, scopes)
            if access_token && !access_token.expired?
              return access_token
            end
          end
          Doorkeeper::AccessToken.create!(
            application_id:    application.try(:id),
            resource_owner_id: resource_owner_id,
            scopes:            scopes.to_s,
            expires_in:        expires_in,
            use_refresh_token: use_refresh_token
          )
        end
      end
    end
  end
end
