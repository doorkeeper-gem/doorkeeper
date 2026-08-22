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

        url_client_id = Doorkeeper::ClientIdMetadata.url_client_id?(credentials.uid)

        # Whatever else it goes on to check, a metadata document client is only
        # ever authenticated by the one method its document names.
        return if url_client_id && !authenticated_as_document_declares?(credentials)

        # Credentials that were fully authenticated by their client
        # authentication method (e.g. a verified private_key_jwt assertion)
        # carry no secret to compare — resolve the client by uid alone.
        return find(credentials.uid) if pre_authenticated?(credentials)

        if url_client_id
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

      def self.pre_authenticated?(credentials)
        credentials.respond_to?(:pre_authenticated?) && credentials.pre_authenticated?
      end
      private_class_method :pre_authenticated?

      # A metadata document names the one method it authenticates with, and
      # Section 8.2 requires client authentication "of the registered type",
      # so a method the document did not select must not stand in for the one
      # it did — on every path into this method, not only the pre-authenticated
      # one. A document naming "none" would otherwise also be satisfied by
      # client_secret_basic with an empty password, which by_uid_and_secret
      # resolves as public-client authentication: harmless in itself, since a
      # public client is exactly the one no secret protects, but it is the
      # guarantee that would be uneven, and unevenness is what a host
      # application's own strategy would find.
      #
      # Doorkeeper::Server records the method that produced the credentials.
      # Ones made outside it carry no method name and so cannot satisfy this;
      # for a URL client_id that is the safe answer.
      #
      # Credentials naming no method are refused before the document is
      # looked at: it could not change the answer, and looking is a fetch.
      def self.authenticated_as_document_declares?(credentials)
        used = credentials.authenticated_with if credentials.respond_to?(:authenticated_with)
        return false if used.blank?

        document = Doorkeeper::ClientIdMetadata.document_for(credentials.uid)

        !document.nil? && document.token_endpoint_auth_method == used.to_s
      end
      private_class_method :authenticated_as_document_declares?
    end
  end
end
