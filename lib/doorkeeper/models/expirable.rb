module Doorkeeper
  module Models
    module Expirable
      def expired?
        expires_in && Time.now > expired_time
      end

      def expired_time
        created_at + expires_in.seconds
      end

      def expires_in_seconds
        return nil if expires_in.nil?
        expires = (created_at + expires_in.seconds) - Time.now
        expires_sec = expires.seconds.round(0)
        expires_sec > 0 ? expires_sec : 0
      end
      private :expired_time
    end
  end
end
