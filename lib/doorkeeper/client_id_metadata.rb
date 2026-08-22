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
  # start with "https://".
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

      # The host of a client_id URL, for the consent screen: draft Section 8.5
      # has the server display it alongside whatever the document said about
      # itself, since nothing in the document (client_name included) is
      # verified and the host is the one part of the identity the client
      # demonstrably controls. nil for an opaque client_id.
      def display_host(client_id)
        return unless url_client_id?(client_id)

        URI.parse(client_id).host.presence
      rescue URI::InvalidURIError
        nil
      end

      # Resolves a client_id URL to an application, fetching and validating
      # the metadata document when it is not memoized. Returns nil on any
      # failure (invalid URL, fetch error, invalid document), which callers
      # surface as the usual invalid_client error.
      def resolve(client_id)
        document = document_for(client_id)
        return unless document

        ApplicationFactory.upsert(document)
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
