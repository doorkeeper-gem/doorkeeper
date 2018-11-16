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

    before_validation :generate_uid, :generate_secret, on: :create

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

    # Revokes AccessToken and AccessGrant records that have not been revoked and
    # associated with the specific Application and Resource Owner.
    #
    # @param resource_owner [ActiveRecord::Base]
    #   instance of the Resource Owner model
    #
    def self.revoke_tokens_and_grants_for(id, resource_owner)
      AccessToken.revoke_all_for(id, resource_owner)
      AccessGrant.revoke_all_for(id, resource_owner)
    end

    # We keep a volatile copy of the raw client_secret for initial communication
    # The stored secret may be mapped and not available in cleartext.
    def plaintext_secret
      if perform_secret_hashing?
        @raw_secret
      else
        secret
      end
    end

    private

    def generate_uid
      self.uid = UniqueToken.generate if uid.blank?
    end

    def generate_secret
      return unless secret.blank?

      @raw_secret = UniqueToken.generate
      self.secret = hashed_or_plain_token(@raw_secret)
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
