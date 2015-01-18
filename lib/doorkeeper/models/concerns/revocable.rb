module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = DateTime)
        update_attribute :revoked_at, clock.now
      end

      def revoke_in(time)
        update_attribute :revoked_at, (DateTime.now + time)
      end

      def revoked?
        !!(revoked_at && revoked_at <= DateTime.now)
      end

      def revoke_previous_refresh_token!
        unless previous_refresh_token.nil?
          old_refresh_token = AccessToken.from_refresh_token(previous_refresh_token)
          old_refresh_token.revoke unless old_refresh_token.nil? or old_refresh_token.revoked_at
          update_attribute :previous_refresh_token, nil
        end
      end
    end
  end
end
