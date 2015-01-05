module Doorkeeper
  module Models
    module Ownership
      extend ActiveSupport::Concern

      included do
        belongs_to :owner, polymorphic: true
        validates :owner, presence: true, if: :validate_owner?
      end

      def validate_owner?
        Doorkeeper.configuration.confirm_application_owner?
      end
    end
  end
end
