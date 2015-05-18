module Doorkeeper
  module ApplicationMixin
    extend ActiveSupport::Concern

    include OAuth::Helpers
    include Models::Scopes
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    included do
      has_many :access_grants, dependent: :destroy, class_name: 'Doorkeeper::AccessGrant'
      has_many :access_tokens, dependent: :destroy, class_name: 'Doorkeeper::AccessToken'

      validates :name, :secret, :uid, presence: true
      validates :uid, uniqueness: true
      validates :redirect_uri, redirect_uri: true

      before_validation :generate_uid, :generate_secret, on: :create

      if respond_to?(:attr_accessible)
        attr_accessible :name, :redirect_uri
      end
    end

    module ClassMethods
      def by_uid_and_secret(uid, secret)
        where(uid: uid.to_s, secret: secret.to_s).limit(1).to_a.first
      end

      def by_uid(uid)
        where(uid: uid.to_s).limit(1).to_a.first
      end
    end

    private

    def generate_uid
      self.uid ||= UniqueToken.generate
    end

    def generate_secret
      self.secret ||= UniqueToken.generate
    end
  end
end
