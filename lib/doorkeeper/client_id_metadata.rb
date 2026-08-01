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

      # Whether the application is a row ApplicationFactory materialized,
      # read off the stamp the factory puts on every row it creates. What
      # the stamp says about a row's origin holds whether or not the feature
      # is currently enabled.
      def materialized_row?(application)
        application.respond_to?(:client_id_metadata_materialized_at) &&
          application.client_id_metadata_materialized_at.present?
      end
    end
  end
end
