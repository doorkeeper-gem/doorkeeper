# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  module Application
    extend ActiveSupport::Concern

    included do
      self.table_name = "#{table_name_prefix}oauth_applications#{table_name_suffix}"

      include ::Doorkeeper::ApplicationMixin

      has_many :access_grants,
               foreign_key: :application_id,
               dependent: :delete_all,
               class_name: Doorkeeper.config.access_grant_class

      has_many :access_tokens,
               foreign_key: :application_id,
               dependent: :delete_all,
               class_name: Doorkeeper.config.access_token_class

      validates :name, :secret, :uid, presence: true
      validates :uid, uniqueness: { case_sensitive: true }
      validates :redirect_uri, "doorkeeper/redirect_uri": true
      validates :confidential, inclusion: { in: [true, false] }

      validate :scopes_match_configured, if: :enforce_scopes?

      before_validation :generate_uid, :generate_secret, on: :create

      has_many :authorized_tokens,
               -> { where(revoked_at: nil) },
               foreign_key: :application_id,
               class_name: Doorkeeper.config.access_token_class

      has_many :authorized_applications,
               through: :authorized_tokens,
               source: :application

      # Generates a new secret for this application, intended to be used
      # for rotating the secret or in case of compromise.
      #
      # @return [String] new transformed secret value
      #
      def renew_secret
        @raw_secret = Doorkeeper::OAuth::Helpers::UniqueToken.generate
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

      # This is the right way how we want to override ActiveRecord #to_json
      #
      # @return [String] entity attributes as JSON
      #
      def as_json(options = {})
        hash = super

        hash["secret"] = plaintext_secret if hash.key?("secret")
        hash
      end

      private

      def generate_uid
        self.uid = Doorkeeper::OAuth::Helpers::UniqueToken.generate if uid.blank?
      end

      def generate_secret
        return unless secret.blank?

        renew_secret
      end

      def scopes_match_configured
        if scopes.present? && !Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
          scope_str: scopes.to_s,
          server_scopes: Doorkeeper.configuration.scopes,
        )
          errors.add(:scopes, :not_match_configured)
        end
      end

      def enforce_scopes?
        Doorkeeper.config.enforce_configured_scopes?
      end
    end

    class_methods do
      # Returns Applications associated with active (not revoked) Access Tokens
      # that are owned by the specific Resource Owner.
      #
      # @param resource_owner [ActiveRecord::Base]
      #   Resource Owner model instance
      #
      # @return [ActiveRecord::Relation]
      #   Applications authorized for the Resource Owner
      #
      def authorized_for(resource_owner)
        resource_access_tokens = Doorkeeper.config.access_token_model.active_for(resource_owner)
        where(id: resource_access_tokens.select(:application_id).distinct)
      end

      # Revokes AccessToken and AccessGrant records that have not been revoked and
      # associated with the specific Application and Resource Owner.
      #
      # @param resource_owner [ActiveRecord::Base]
      #   instance of the Resource Owner model
      #
      def revoke_tokens_and_grants_for(id, resource_owner)
        Doorkeeper.config.access_token_model.revoke_all_for(id, resource_owner)
        Doorkeeper.config.access_grant_model.revoke_all_for(id, resource_owner)
      end
    end
  end
end
