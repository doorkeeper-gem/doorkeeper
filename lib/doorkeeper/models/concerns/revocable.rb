module Doorkeeper
  module Models
    module Revocable
      extend ActiveSupport::Concern

      def revoke(clock = DateTime)
        update_attribute :revoked_at, clock.now
      end

      def revoked?
        !!(revoked_at && revoked_at <= DateTime.now)
      end
    end
  end
end
