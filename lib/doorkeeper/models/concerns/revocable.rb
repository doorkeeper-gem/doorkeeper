module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = DateTime)
        Doorkeeper.configuration.refresh_token
        update_attribute :revoked_at, clock.now
        Doorkeeper.configuration.refresh_token_revoked_on_use
      end

      def revoke_in(time)
        update_attribute :revoked_at, (DateTime.now + time)
      end

      def revoked?
        !!(revoked_at && revoked_at <= DateTime.now)
      end

      def previous_active_refresh_token
        previous_refresh_token = AccessToken.by_refresh_token(previous_refresh_token) unless previous_refresh_token.nil?
        return nil if previous_refresh_token.nil? or previous_refresh_token.revoked?
        previous_refresh_token
      end

      def revoke_previous_refresh_token!
        old_refresh_token =　previous_active_refresh_token
        if old_refresh_token
          if Doorkeeper.configuration.refresh_token_revoked_in
            old_refresh_token.revoke
          else
            old_refresh_token.revoke_in(Doorkeeper.configuration.refresh_token_revoked_in)
          end
        end
        update_attribute :previous_refresh_token, nil
      end
    end
  end
end
