# frozen_string_literal: true

# The full registry rather than just credentials: requiring only
# client_authentication/credentials fires the ClientAuthentication autoload
# mid-load, which re-requires the in-progress file and warns under -w
# ("circular require considered harmful").
require "doorkeeper/client_authentication"

module Doorkeeper
  module OAuth
    class Client
      # @deprecated Moved to +Doorkeeper::ClientAuthentication::Credentials+.
      #   This alias keeps the long-standing +Doorkeeper::OAuth::Client::Credentials+
      #   constant resolvable for one release so referencing code does not raise
      #   +NameError+; update references to the new constant. Note the legacy
      #   +.from_request+/+.from_basic+/+.from_params+ class methods are gone —
      #   client credential extraction now goes through the client authentication
      #   registry (RFC 6749 §2.3). Marked with +deprecate_constant+, so Ruby
      #   warns on access when deprecation warnings are enabled
      #   (+Warning[:deprecated] = true+ or +-W:deprecated+).
      Credentials = Doorkeeper::ClientAuthentication::Credentials
      deprecate_constant :Credentials

      attr_reader :application

      delegate :id, :name, :uid, :redirect_uri, :scopes, :confidential, to: :@application

      def initialize(application)
        @application = application
      end

      # @param uid [String] the client identifier to look up
      # @param method [#call] how to look a uid up. A URL client_id is looked
      #   up as well, because a registered application may hold it (draft
      #   Section 7.2) and then resolves like any other; only a URL no
      #   application holds — or one held by a row this feature materialized
      #   — is resolved through its metadata document instead. For that URL
      #   the finder answers whether a registered application holds it, and
      #   the row itself then comes from the configured application model
      #   rather than from the finder: a metadata document client belongs to
      #   the server, not to whatever scope a custom finder narrows to.
      def self.find(uid, method = Doorkeeper.config.application_model.method(:by_uid))
        application = method.call(uid)

        if Doorkeeper::ClientIdMetadata.resolves_through_document?(uid, application)
          application = Doorkeeper::ClientIdMetadata.resolve(uid)
          return application && new(application)
        end

        return unless application
        # A row materialized from a metadata document keeps its stamp after
        # the feature is disabled, and must not keep working as if someone
        # had registered it (see ClientIdMetadata.orphaned_materialized_row?).
        return if Doorkeeper::ClientIdMetadata.orphaned_materialized_row?(application)

        new(application)
      end

      def self.authenticate(credentials, method = Doorkeeper.config.application_model.method(:by_uid_and_secret))
        return if credentials.blank?

        # Credentials that were fully authenticated by their client
        # authentication method (e.g. a verified private_key_jwt assertion)
        # carry no secret to compare — resolve the client by uid alone.
        return find(credentials.uid) if credentials.respond_to?(:pre_authenticated?) && credentials.pre_authenticated?

        return unless (application = method.call(credentials.uid, credentials.secret))

        new(application)
      end
    end
  end
end
