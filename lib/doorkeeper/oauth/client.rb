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

        url_client_id = document_client_id?(credentials.uid)
        return if provenance_disagrees?(credentials, url_client_id)
        return if url_client_id && refused_as_document_client?(credentials)

        # Credentials that were fully authenticated by their client
        # authentication method (e.g. a verified private_key_jwt assertion)
        # carry no secret to compare — resolve the client by uid alone.
        return resolved_for(credentials) if pre_authenticated?(credentials)

        # A document client's document is resolved before the regular lookup
        # so the application row exists and reflects the current document;
        # the lookup below still applies the public-client check against it.
        return if url_client_id && Doorkeeper::ClientIdMetadata.resolve(credentials.uid).nil?

        return unless (application = method.call(credentials.uid, credentials.secret))
        # As in find: a stamped row outliving the feature is no registered
        # client, whatever credentials were presented for it.
        return if Doorkeeper::ClientIdMetadata.orphaned_materialized_row?(application)

        new(application)
      end

      def self.pre_authenticated?(credentials)
        credentials.respond_to?(:pre_authenticated?) && credentials.pre_authenticated?
      end
      private_class_method :pre_authenticated?

      # A method that authenticated the client already decided where the keys
      # it verified against came from — a metadata document's, or a registered
      # application's — and that decision is the one this lookup honours. The
      # uid is resolved again here, and what it resolves to can have changed in
      # between: an application row holding the URL can be registered or
      # removed, and a materialized row's stamp can be cleared to adopt it.
      # The window is not instantaneous either, since a document client's keys
      # are fetched over the network. Resolving the other way round would hand
      # an assertion verified against whatever a URL serves the registered
      # application that now holds that URL — whose keys the signer never had
      # — so a provenance that no longer agrees refuses the credentials rather
      # than resolving them. Credentials stating none (every method that does
      # not make the distinction) are resolved as before.
      # The provenance check above was made against a lookup of its own, and
      # +find+ makes another: a row holding the URL can be registered, or have
      # been removed, in between. So what +find+ resolved is held to the same
      # answer, read off the row this time — the stamp is what says which kind
      # of client a row is — and a resolution that came out the other kind is
      # no client at all rather than the one the assertion was not verified
      # against.
      def self.resolved_for(credentials)
        client = find(credentials.uid)
        return unless client
        return if provenance_disagrees?(
          credentials,
          Doorkeeper::ClientIdMetadata.materialized_row?(client.application),
        )

        client
      end
      private_class_method :resolved_for

      def self.provenance_disagrees?(credentials, url_client_id)
        return false unless credentials.respond_to?(:from_metadata_document?)

        stated = credentials.from_metadata_document?
        return false if stated.nil?

        stated != url_client_id
      end
      private_class_method :provenance_disagrees?

      # The two rules every metadata document client is held to, whatever
      # else authenticate goes on to check, in the order that costs least.
      # Shared-secret authentication is forbidden for URL client_ids (draft
      # Section 4.1): no secret is ever established with such a client, so a
      # presented secret is refused outright — never compared against the
      # materialized row's auto-generated (or a pre-existing row's) secret,
      # and before the document is looked at, since no document could change
      # the answer and looking is a fetch. And a document client is only ever
      # authenticated by the one method its document names.
      def self.refused_as_document_client?(credentials)
        credentials.secret.present? || !authenticated_as_document_declares?(credentials)
      end
      private_class_method :refused_as_document_client?

      # The lookup resolves_through_document? needs, made only for URL-shaped
      # uids so that opaque ones cost no extra query.
      def self.document_client_id?(uid)
        return false unless Doorkeeper::ClientIdMetadata.url_client_id?(uid)

        registered = Doorkeeper.config.application_model.by_uid(uid)
        Doorkeeper::ClientIdMetadata.resolves_through_document?(uid, registered)
      end
      private_class_method :document_client_id?

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
      # On the request path Doorkeeper::Server records the method that
      # produced the credentials, overwriting whatever the strategy set for
      # itself, so what is compared here is the server's own record of which
      # strategy ran. Credentials assembled outside that path carry whatever
      # name their maker chose — PrivateKeyJwt names itself when called
      # directly, and VerifiedCredentials takes the name as public API — so
      # this check is only as strong as that record: a caller building
      # credentials by hand is trusted to name the method honestly.
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
