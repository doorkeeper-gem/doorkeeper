module Doorkeeper
  module Models
    module Accessible
      def accessible?
        !expired? && !revoked?
      end
    end
  end
end
