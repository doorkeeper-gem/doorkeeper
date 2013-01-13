module Doorkeeper
  module Models
    module Authenticatable
      extend ActiveSupport::Concern

      module ClassMethods
        def find_for_oauth_authentication(uid)
          where(:uid => uid).first
        end

        def oauth_authenticate(uid, secret)
          return if uid.blank? || secret.blank?
          client = find_for_oauth_authentication(uid)
          if client && client.oauth_authenticate(secret)
            client
          else
            nil
          end
        end
      end

      def oauth_authenticate(secret)
        self.secret == secret
      end
    end
  end
end
