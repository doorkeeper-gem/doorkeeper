module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = Time)
        update_attribute :revoked_at, clock.now.utc
      end

      def revoked?
        !!(revoked_at && revoked_at <= Time.now.utc)
      end
    end
  end
end
