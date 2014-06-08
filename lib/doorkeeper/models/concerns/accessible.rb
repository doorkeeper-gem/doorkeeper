module Doorkeeper
  module Models
    module Accessible
      extend ActiveSupport::Concern

      def accessible?
        !expired? && !revoked?
      end
    end
  end
end
