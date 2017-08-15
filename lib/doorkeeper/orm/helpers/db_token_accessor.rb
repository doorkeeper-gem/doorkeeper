module Doorkeeper
  module Orm
    module Helpers
      module DbTokenAccessor
        def self.find_or_create_token(application: nil,
          resource_owner: nil,
          token: nil,
          refresh_token: nil,
          scopes: nil)
          if token.present?
            AccessToken.find_by(token: token.to_s)
          elsif refresh_token.present?
            AccessToken.find_by(refresh_token: refresh_token.to_s)
          end
        end
      end
    end
  end
end
