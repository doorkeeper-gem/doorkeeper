module Doorkeeper
  module Orm
    module Helpers
      module DbTokenAccessor
        def self.get_by_token(token)
          AccessToken.find_by(token: token.to_s)
        end

        def self.get_by_refresh_token(refresh_token)
          AccessToken.find_by(refresh_token: refresh_token.to_s)
        end

        def self.get_tokens_by_app_and_resource_owner(application, resource_owner)
          AccessToken.where(application_id: application.id,
                            resource_owner_id: resource_owner.id,
                            revoked_at: nil)
        end
      end
    end
  end
end
