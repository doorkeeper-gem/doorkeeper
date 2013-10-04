module Doorkeeper
  module Models
    module Revocable
      def revoke(clock = DateTime)
        if respond_to? :update_column
          update_column :revoked_at, clock.now
        else
          update revoked_at: clock.now
        end
      end

      def revoked?
        revoked_at.present?
      end
    end
  end
end
