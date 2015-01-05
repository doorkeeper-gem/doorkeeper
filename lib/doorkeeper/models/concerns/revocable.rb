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
    end
  end
end
