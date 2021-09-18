# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  module AccessGrant
    extend ActiveSupport::Concern

    included do
      self.table_name = compute_doorkeeper_table_name
      self.strict_loading_by_default = false if respond_to?(:strict_loading_by_default)

      include ::Doorkeeper::AccessGrantMixin

      belongs_to :application, class_name: Doorkeeper.config.application_class.to_s,
                               optional: true,
                               inverse_of: :access_grants

      if Doorkeeper.config.polymorphic_resource_owner?
        belongs_to :resource_owner, polymorphic: true, optional: false
      else
        validates :resource_owner_id, presence: true
      end

      validates :application_id,
                :token,
                :expires_in,
                presence: true

      validates :redirect_uri,
                presence: true,
                on: :create,
                unless: :redirect_uri_optional_during_authorization?

      validates :redirect_uri,
                presence: true,
                on: :update,
                if: :validate_redirect_uri_on_update?

      validates :token, uniqueness: { case_sensitive: true }

      before_validation :generate_token, on: :create

      # We keep a volatile copy of the raw token for initial communication
      # The stored refresh_token may be mapped and not available in cleartext.
      #
      # Some strategies allow restoring stored secrets (e.g. symmetric encryption)
      # while hashing strategies do not, so you cannot rely on this value
      # returning a present value for persisted tokens.
      def plaintext_token
        if secret_strategy.allows_restoring_secrets?
          secret_strategy.restore_secret(self, :token)
        else
          @raw_token
        end
      end

      private

      # Generates token value with UniqueToken class.
      #
      # @return [String] token value
      #
      def generate_token
        @raw_token = Doorkeeper::OAuth::Helpers::UniqueToken.generate
        secret_strategy.store_secret(self, :token, @raw_token)
      end

      def redirect_uri_optional_during_authorization?
        Doorkeeper.config.redirect_uri_optional_during_authorization
      end

      def redirect_uri_required_during_authorization?
        !redirect_uri_optional_during_authorization?
      end

      def validate_redirect_uri_on_update?
        redirect_uri_required_during_authorization? && redirect_uri_changed?
      end
    end

    module ClassMethods
      private

      def compute_doorkeeper_table_name
        table_name = "oauth_access_grant"
        table_name = table_name.pluralize if pluralize_table_names
        "#{table_name_prefix}#{table_name}#{table_name_suffix}"
      end
    end
  end
end
