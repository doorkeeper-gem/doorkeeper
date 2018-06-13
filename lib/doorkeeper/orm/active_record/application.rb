module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_applications#{table_name_suffix}".to_sym

    include ApplicationMixin
    include ActiveModel::MassAssignmentSecurity if defined?(::ProtectedAttributes)

    has_many :access_grants, dependent: :delete_all, class_name: 'Doorkeeper::AccessGrant'
    has_many :access_tokens, dependent: :delete_all, class_name: 'Doorkeeper::AccessToken'

    validates :name, :secret, :uid, presence: true
    validates :uid, uniqueness: true
    validates :redirect_uri, redirect_uri: true
    validates :confidential, inclusion: { in: [true, false] }

    validate :scopes_match_configured, if: :enforce_scopes?

    before_validation :generate_uid, on: :create

    if secrets_encryption_enabled?
      before_validation :generate_encrypted_secret, on: :create
    else
      before_validation :generate_secret, on: :create
    end

    has_many :authorized_tokens, -> { where(revoked_at: nil) }, class_name: 'AccessToken'
    has_many :authorized_applications, through: :authorized_tokens, source: :application

    # Returns Applications associated with active (not revoked) Access Tokens
    # that are owned by the specific Resource Owner.
    #
    # @param resource_owner [ActiveRecord::Base]
    #   Resource Owner model instance
    #
    # @return [ActiveRecord::Relation]
    #   Applications authorized for the Resource Owner
    #
    def self.authorized_for(resource_owner)
      resource_access_tokens = AccessToken.active_for(resource_owner)
      where(id: resource_access_tokens.select(:application_id).distinct)
    end

    def secret
      @secret ||= Doorkeeper.configuration.decryption_handler.call(self.encrypted_secret)
    end

    private

    def generate_uid
      self.uid = UniqueToken.generate if uid.blank?
    end

    def generate_secret
      self.secret = UniqueToken.generate if secret.blank?
    end

    def generate_encrypted_secret
      secret = UniqueToken.generate
      self.encrypted_secret = Doorkeeper.configuration.encryption_handler.call(secret)
    end

    def scopes_match_configured
      if scopes.present? &&
         !ScopeChecker.valid?(scopes.to_s, Doorkeeper.configuration.scopes)
        errors.add(:scopes, :not_match_configured)
      end
    end

    def enforce_scopes?
      Doorkeeper.configuration.enforce_configured_scopes?
    end
  end
end
