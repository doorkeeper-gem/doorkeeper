# frozen_string_literal: true

module Doorkeeper
  module Models
    module Revocable
      # Revokes the object (updates `:revoked_at` attribute setting its value
      # to the specific time).
      #
      # @param clock [Time] time object
      #
      def revoke(clock = Time)
        return if revoked?

        # Wrap in with_primary_role if the model class supports it
        if self.class.respond_to?(:with_primary_role)
          self.class.with_primary_role do
            update_attribute(:revoked_at, clock.now.utc)
          end
        else
          update_attribute(:revoked_at, clock.now.utc)
        end
      end

      # Indicates whether the object has been revoked.
      #
      # @return [Boolean] true if revoked, false in other case
      #
      def revoked?
        !!(revoked_at && revoked_at <= Time.now.utc)
      end
    end
  end
end
