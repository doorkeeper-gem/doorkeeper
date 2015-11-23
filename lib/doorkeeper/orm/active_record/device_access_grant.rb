module Doorkeeper
  class DeviceAccessGrant < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_device_access_grants#{table_name_suffix}".to_sym

    include OAuth::Helpers
    include Models::Expirable
    include Models::Revocable
    include Models::Accessible
    include Models::Scopes
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    belongs_to :application, class_name: 'Doorkeeper::Application', inverse_of: :device_access_grants

    if respond_to?(:attr_accessible)
      attr_accessible :application_id, :expires_in, :scopes, :resource_owner_id
    end

    validates :application_id, :token, :user_token, :expires_in, presence: true
    validates :token, uniqueness: true
    validates :user_token, uniqueness: true

    before_validation :generate_token, on: :create
    before_validation :generate_user_token, on: :create

    def self.by_token(token)
      where(token: token.to_s).limit(1).to_a.first
    end

    def too_fast?
      interval = Time.now.to_i - last_polled_at.to_i
      interval < polling_interval
    end

    def polled
      update_attribute(:last_polled_at, Time.now)
    end

    private

    def polling_interval
      Doorkeeper.configuration.device_polling_interval
    end

    def generate_token
      self.token = UniqueToken.generate
    end

    def generate_user_token
      self.user_token = UniqueToken.generate(size: 3).upcase
    end
  end
end
