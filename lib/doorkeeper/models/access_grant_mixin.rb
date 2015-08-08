module Doorkeeper
  module AccessGrantMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Expirable
    include Models::Revocable
    include Models::Accessible
    include Models::Scopes
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    included do
      belongs_to :application, class_name: 'Doorkeeper::Application', inverse_of: :access_grants

      if respond_to?(:attr_accessible)
        attr_accessible :resource_owner_id, :application_id, :expires_in, :redirect_uri, :scopes
      end

      validates :resource_owner_id, :application_id, :token, :expires_in, :redirect_uri, presence: true
      validates :token, uniqueness: true

      before_validation :generate_token, on: :create
    end

    module ClassMethods
      def by_token(token)
        where(token: token.to_s).limit(1).to_a.first
      end
    end

    private

    def generate_token
      self.token = UniqueToken.generate
    end
  end
end
