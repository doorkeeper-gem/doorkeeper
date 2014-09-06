module Doorkeeper
  module ApplicationEssential
    extend ActiveSupport::Concern

    include OAuth::Helpers

    included do
      has_many :access_grants, dependent: :destroy, class_name: 'Doorkeeper::AccessGrant'
      has_many :access_tokens, dependent: :destroy, class_name: 'Doorkeeper::AccessToken'

      validates :name, :secret, :uid, presence: true
      validates :uid, uniqueness: true
      validates :redirect_uri, redirect_uri: true

      before_validation :generate_uid, :generate_secret, on: :create

      if ::Rails.version.to_i < 4 || defined?(::ProtectedAttributes)
        attr_accessible :name, :redirect_uri
      end
    end

    module ClassMethods
      def by_uid_and_secret(uid, secret)
        where(uid: uid, secret: secret).first
      end

      def by_uid(uid)
        where(uid: uid).first
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
