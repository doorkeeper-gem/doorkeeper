module Doorkeeper
  module Models
    module Expirable
      def expired?
        expires_in && Time.now > expired_time
      end

      def time_left
        expired? ? 0 : expired_time - Time.now
      end

      def expired_time
        created_at + expires_in.seconds
      end
      private :expired_time
    end
  end
end
