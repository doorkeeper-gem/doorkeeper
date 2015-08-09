module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = DateTime)
        update_attribute :revoked_at, clock.now
        Doorkeeper.configuration.refresh_token_revoked_on_use
      end

      def revoked?
        !!(revoked_at && revoked_at <= DateTime.now)
      end

      def revoke_previous_refresh_token!
        return if previous_refresh_token.nil?
        old_refresh_token = AccessToken.by_refresh_token(previous_refresh_token)
        old_refresh_token = nil if old_refresh_token.nil? or old_refresh_token.revoked?
        old_refresh_token.revoke if old_refresh_token
        update_attribute :previous_refresh_token, nil
      end
    end
  end
end
