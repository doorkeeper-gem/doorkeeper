module Doorkeeper
  module Models
    module Ownership
      def validate_owner?
        Doorkeeper.configuration.confirm_application_owner?
      end

      def self.included(base)
        base.class_eval do
          belongs_to :owner, polymorphic: true
          validates :owner, presence: true, if: :validate_owner?
        end
      end
    end
  end
end
