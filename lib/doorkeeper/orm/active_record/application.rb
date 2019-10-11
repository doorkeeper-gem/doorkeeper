# frozen_string_literal: true

module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_applications#{table_name_suffix}"

    include ApplicationMixin

    has_many :access_grants, dependent: :delete_all, class_name: "Doorkeeper::AccessGrant"
    has_many :access_tokens, dependent: :delete_all, class_name: "Doorkeeper::AccessToken"

    validates :name, :secret, :uid, presence: true
    validates :uid, uniqueness: { case_sensitive: true }
    validates :redirect_uri, "doorkeeper/redirect_uri": true
    validates :confidential, inclusion: { in: [true, false] }

    validate :scopes_match_configured, if: :enforce_scopes?

    before_validation :generate_uid, :generate_secret, on: :create

    has_many :authorized_tokens, -> { where(revoked_at: nil) }, class_name: "AccessToken"
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

    # Generates (or regenerates) the secret for this application.
    #
    # @param allow_overwrite [Boolean]
    #   whether to allow overwriting an existing secret
    #
    def generate_secret(allow_overwrite = false)
      return unless secret.blank? || allow_overwrite

      @raw_secret = UniqueToken.generate
      secret_strategy.store_secret(self, :secret, @raw_secret)
    end

    # We keep a volatile copy of the raw secret for initial communication
    # The stored refresh_token may be mapped and not available in cleartext.
    #
    # Some strategies allow restoring stored secrets (e.g. symmetric encryption)
    # while hashing strategies do not, so you cannot rely on this value
    # returning a present value for persisted tokens.
    def plaintext_secret
      if secret_strategy.allows_restoring_secrets?
        secret_strategy.restore_secret(self, :secret)
      else
        @raw_secret
      end
    end

    def to_json(options = nil)
      serializable_hash(except: :secret)
        .merge(secret: plaintext_secret)
        .to_json(options)
    end

    private

    def generate_uid
      self.uid = UniqueToken.generate if uid.blank?
    end

    def scopes_match_configured
      if scopes.present? &&
         !ScopeChecker.valid?(scope_str: scopes.to_s,
                              server_scopes: Doorkeeper.configuration.scopes)
        errors.add(:scopes, :not_match_configured)
      end
    end

    def enforce_scopes?
      Doorkeeper.configuration.enforce_configured_scopes?
    end
  end
end
