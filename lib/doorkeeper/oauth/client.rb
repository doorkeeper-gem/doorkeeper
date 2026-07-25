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
      # @param method [#call] how to look an opaque uid up. Not consulted for
      #   URL client_ids, which are resolved through their metadata document
      #   rather than through the application table.
      def self.find(uid, method = Doorkeeper.config.application_model.method(:by_uid))
        if Doorkeeper::ClientIdMetadata.url_client_id?(uid)
          application = Doorkeeper::ClientIdMetadata.resolve(uid)
          return application && new(application)
        end

        return unless (application = method.call(uid))

        new(application)
      end

      def self.authenticate(credentials, method = Doorkeeper.config.application_model.method(:by_uid_and_secret))
        return if credentials.blank?

        # Credentials that were fully authenticated by their client
        # authentication method (e.g. a verified private_key_jwt assertion)
        # carry no secret to compare — resolve the client by uid alone.
        return find(credentials.uid) if credentials.respond_to?(:pre_authenticated?) && credentials.pre_authenticated?

        if Doorkeeper::ClientIdMetadata.url_client_id?(credentials.uid)
          # Shared-secret authentication is forbidden for URL client_ids
          # (draft Section 4.1): no secret is ever established with such a
          # client, so a presented secret is rejected outright — never
          # compared against the materialized row's auto-generated (or a
          # pre-existing row's) secret.
          return if credentials.secret.present?

          # The document is resolved before the regular lookup so the
          # application row exists and reflects the current document; the
          # lookup below still applies the public-client check against it.
          return if Doorkeeper::ClientIdMetadata.resolve(credentials.uid).nil?
        end

        return unless (application = method.call(credentials.uid, credentials.secret))

        new(application)
      end
    end
  end
end
