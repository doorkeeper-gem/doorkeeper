module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = Time)
        update_attribute :revoked_at, clock.now
      end

      def revoked?
        !!(revoked_at && revoked_at <= Time.now)
      end

      def revoke_in(time)
        update_attribute :revoked_at, Time.now + time
      end

      def revoke_previous_refresh_token!
        if old_refresh_token && !old_refresh_token.revoked?
          old_refresh_token.revoke_in(refresh_token_revoked_in)
        end
        update_attribute :previous_refresh_token, "" if previous_refresh_token != ""
      end

      def old_refresh_token
        @old_refresh_token ||= AccessToken.by_refresh_token(previous_refresh_token)
      end

      def refresh_token_revoked_in
        Doorkeeper.configuration.refresh_token_revoked_in
      end

      def configuration
        Doorkeeper.configuration
      end
    end
  end
end
