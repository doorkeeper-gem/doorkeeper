# frozen_string_literal: true

require "uri"

require "doorkeeper/client_id_metadata/url_validator"
require "doorkeeper/client_id_metadata/document"
require "doorkeeper/client_id_metadata/application_factory"

module Doorkeeper
  # Client ID Metadata Documents (draft-ietf-oauth-client-id-metadata-document):
  # clients identify themselves with an https:// client_id from which the
  # authorization server fetches their metadata, instead of pre-registering.
  # Section numbers cited here and elsewhere in Doorkeeper are draft-02's,
  # which renumbered most of the document.
  #
  # Disabled unless +use_client_id_metadata_documents+ is declared in the
  # Doorkeeper initializer (read back as
  # +Doorkeeper.config.client_id_metadata_documents?+). When enabled,
  # URL-shaped client_ids are resolved through this module while opaque
  # client_ids keep resolving against registered applications, so both kinds
  # of client coexist (draft Section 7.1); Doorkeeper's generated uids never
  # start with "https://", and a registered application that was given a
  # URL-shaped uid anyway — a pre-registered Client Identifier URL, which
  # Section 7.2 permits — keeps resolving as that registered application
  # rather than being fetched and adopted. The rows this module materializes
  # are told apart by the stamp ApplicationFactory puts on them, not by their
  # uid's shape.
  module ClientIdMetadata
    CLIENT_ID_SCHEME_PREFIX = "https://"

    class << self
      def enabled?
        Doorkeeper.config.client_id_metadata_documents?
      end

      # Whether the given client_id should be treated as a Client ID Metadata
      # Document URL (feature enabled and URL-shaped identifier). The scheme
      # is matched case-insensitively per RFC 3986 Section 3.1; the rest of
      # the identifier is never normalized (the draft compares client_ids as
      # simple strings).
      def url_client_id?(client_id)
        enabled? && client_id.to_s[0, CLIENT_ID_SCHEME_PREFIX.length].casecmp?(CLIENT_ID_SCHEME_PREFIX)
      end

      # The host of a document client's client_id URL, for the consent
      # screen: draft Section 8.5 has the server display it alongside
      # whatever the document said about itself, since nothing in the
      # document (client_name included) is verified and the host is the one
      # part of the identity the client demonstrably controls. nil for a
      # registered application — one with an opaque uid, and equally one
      # pre-registered under a URL-shaped uid (Section 7.2): nothing was
      # fetched from that URL, so its host vouches for nothing.
      # A non-default port is kept: two client_ids differing only in it are
      # two clients (the draft compares the URLs as strings), and dropping it
      # would show them under one name.
      #
      # Asked of the row's provenance alone, not of the option: a row this
      # feature materialized keeps its host after the option is turned off,
      # where it still appears on the authorized applications page and its
      # already-issued tokens are still live. That page is where a resource
      # owner decides what to revoke, and leaving the document's unverified
      # client_name standing there by itself is the opposite of what Section
      # 8.5 asks for. The uid of such a row is an https:// URL the factory
      # validated before writing it; anything else parses to no host and is
      # answered nil below.
      def display_host(application)
        return unless materialized_row?(application)

        uri = URI.parse(application.uid)
        host = uri.host.presence
        return unless host
        return host if uri.port.nil? || uri.port == uri.default_port

        "#{host}:#{uri.port}"
      rescue URI::InvalidURIError
        nil
      end

      # Whether a client_id is resolved through its metadata document rather
      # than through the application table. Being URL-shaped (with the
      # feature enabled) is necessary but not sufficient: draft Section 7.2
      # permits pre-registering Client Identifier URLs, and Section 7.1 says
      # the https:// prefix cannot tell such a registration from a document
      # client — the stamp can. A URL an un-stamped application holds keeps
      # resolving as that registered application, and is never fetched, the
      # same as while the feature is off. +registered+ is the application
      # table's answer for the uid, nil when no application holds it.
      def resolves_through_document?(client_id, registered)
        url_client_id?(client_id) && (registered.nil? || materialized_row?(registered))
      end

      # Resolves a client_id URL to an application, fetching and validating
      # the metadata document when it is not memoized. Returns nil on any
      # failure (invalid URL, fetch error, invalid document, or a uid held by
      # a registered application — see resolves_through_document? for the
      # check callers make before fetching), which callers surface as the
      # usual invalid_client error.
      def resolve(client_id)
        document = document_for(client_id)
        return unless document

        ApplicationFactory.upsert(document)
      end

      # Whether the application is a row ApplicationFactory materialized,
      # read off the stamp the factory puts on every row it creates. What
      # the stamp says about a row's origin holds whether or not the feature
      # is currently enabled.
      def materialized_row?(application)
        application.respond_to?(:client_id_metadata_materialized_at) &&
          application.client_id_metadata_materialized_at.present?
      end

      # Whether the application is a row the factory materialized while the
      # feature has since been disabled. Such a row must not fall through to
      # opaque resolution as if someone had registered it: nothing refreshes
      # it any more, so its redirect URIs, scopes and keys are whatever its
      # URL last served, vouched for by no one — and no one registered it in
      # the first place. Registered applications, URL-shaped uid or not,
      # carry no stamp and are untouched. A deployment that means to keep
      # such a client for good can clear its stamp and own it as a
      # registered application from then on.
      def orphaned_materialized_row?(application)
        !enabled? && materialized_row?(application)
      end

      # Whether this client is one nobody registered: a public ("none")
      # client resolved through a metadata document. Such a client_id is
      # minted by publishing a document at a URL, so a check that only asks
      # "is a client authenticated?" proves nothing about who is asking —
      # which is what the client gates on the introspection endpoint (RFC
      # 7662 Section 4, "to prevent token scanning attacks"), the
      # client_credentials grant (RFC 6749 Section 4.4) and the password grant
      # are there for. A confidential document client is different: it holds a
      # key its document published, and only its holder can present one.
      def public_document_client?(client)
        # Asked before anything is read off the client, so the predicate is a
        # true no-op while the feature is off: the callers sit on the token,
        # introspection and password-grant paths, and the object they hand
        # over is public API.
        return false unless enabled?

        application = client&.application
        return false if application.nil?

        resolves_through_document?(application.uid, application) && !application.confidential?
      end

      # Whether the resource owner is asked to consent to this client on every
      # authorization, rather than having an earlier authorization stand in.
      # True for a row this feature materialized: everything behind its URL —
      # the redirect URIs and keys included — is whatever it serves today
      # (draft Sections 8.3 / 8.4). Read by the engine's own consent gate and
      # exposed for the extensions that have gates of their own.
      def consent_required_every_time?(application)
        materialized_row?(application)
      end

      # The validated metadata document for a client_id URL, or nil. Also
      # used by client authentication methods that need document contents
      # (e.g. jwks) rather than the materialized application.
      def document_for(client_id)
        return unless url_client_id?(client_id)
        return unless UrlValidator.valid?(client_id)

        document_cache.fetch(client_id) do
          Document.parse!(client_id, HttpFetcher.new.fetch(client_id))
        end
      rescue HttpFetcher::FetchError, Document::ValidationError
        nil
      end

      def document_cache
        @document_cache ||= DocumentCache.new
      end
    end
  end
end
