module Doorkeeper
  class AccessToken < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_access_tokens#{table_name_suffix}".to_sym

    include AccessTokenMixin
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    belongs_to_options = {
      class_name: 'Doorkeeper::Application',
      inverse_of: :access_tokens
    }

    if defined?(ActiveRecord::Base) && ActiveRecord::VERSION::MAJOR >= 5
      belongs_to_options[:optional] = true
    end

    belongs_to :application, belongs_to_options

    if secrets_encryption_enabled?
      validates :encrypted_refresh_token, presence: true, if: :use_refresh_token?
      validates :hashed_refresh_token, presence: true, uniqueness: true, if: :use_refresh_token?

      validates :encrypted_token, presence: true
      validates :hashed_token, presence: true, uniqueness: true
    else
      validates :token, presence: true, uniqueness: true
      validates :refresh_token, uniqueness: true, if: :use_refresh_token?
    end

      # self.encrypted_refresh_token = Doorkeeper.configuration.encryption_handler.call(refresh_token)
      # self.hashed_refresh_token = Doorkeeper.configuration.hashing_handler.call(refresh_token)

    # @attr_writer [Boolean, nil] use_refresh_token
    #   indicates the possibility of using refresh token
    attr_writer :use_refresh_token

    if secrets_encryption_enabled?
      before_validation :generate_encrypted_token, on: :create
      before_validation :generate_encrypted_refresh_token, on: :create, if: :use_refresh_token?
    else
      before_validation :generate_token, on: :create
      before_validation :generate_refresh_token, on: :create, if: :use_refresh_token?
    end

    # Searches for not revoked Access Tokens associated with the
    # specific Resource Owner.
    #
    # @param resource_owner [ActiveRecord::Base]
    #   Resource Owner model instance
    #
    # @return [ActiveRecord::Relation]
    #   active Access Tokens for Resource Owner
    #
    def self.active_for(resource_owner)
      where(resource_owner_id: resource_owner.id, revoked_at: nil)
    end

    def self.refresh_token_revoked_on_use?
      column_names.include?('previous_refresh_token')
    end

    def token
      @token ||= Doorkeeper.configuration.decryption_handler.call(self.encrypted_token)
    end

    def refresh_token
      @refresh_token ||= Doorkeeper.configuration.decryption_handler.call(self.encrypted_refresh_token)
    end
  end
end
