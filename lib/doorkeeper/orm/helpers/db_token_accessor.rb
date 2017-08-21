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
          AccessToken
            .where(application_id: application.try(:id),
                   resource_owner_id: resource_owner.try(:id),
                   revoked_at: nil)
            .order(created_at: :desc)
        end

        def self.generate_token(application, resource_owner, scopes, expires_in, created_at)
          generator = Doorkeeper.configuration.access_token_generator.constantize
          generator.generate(
            resource_owner_id: resource_owner.try(:id),
            scopes: scopes,
            application: application,
            expires_in: expires_in,
            created_at: created_at
          )
        end

        def self.generate_refresh_token
          Doorkeeper::OAuth::Helpers::UniqueToken.generate
        end

        def self.create(application, resource_owner, scopes, expires_in, use_refresh_token)
          AccessToken.create!(
            application_id: application.try(:id),
            resource_owner_id: resource_owner.try(:id),
            scopes: scopes.to_s,
            expires_in: expires_in,
            use_refresh_token: use_refresh_token
          )
        end
      end
    end
  end
end
