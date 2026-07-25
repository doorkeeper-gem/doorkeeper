# frozen_string_literal: true

require "uri"

module Doorkeeper
  module ClientIdMetadata
    # Materializes a validated metadata document as an application record
    # whose uid is the client_id URL itself.
    #
    # A row (rather than a purely in-memory object) is used because access
    # grants and tokens reference their application through a foreign key, so
    # anything without a persisted id cannot ride the existing authorization
    # and token flows. The row carries no authority of its own: it is
    # refreshed from the fetched document on every resolution, and its
    # auto-generated secret is never disclosed nor usable (shared-secret
    # authentication is forbidden for these clients).
    class ApplicationFactory
      # Client resolution happens while serving the authorization endpoint's
      # GET, which Rails routes to a read replica when automatic role
      # switching is enabled, so the write is wrapped like every other write
      # Doorkeeper performs mid-request.
      def self.upsert(document)
        model = Doorkeeper.config.application_model

        model.with_primary_role do
          application = model.find_or_initialize_by(uid: document.client_id)

          application.name = document.client_name.presence || URI.parse(document.client_id).host
          application.redirect_uri = document.redirect_uris
          application.confidential = document.confidential?
          # Assigned even when the document omits it, so dropping the property
          # widens the client back to the server's default scopes instead of
          # leaving a stale restriction behind. Note that with
          # +enforce_configured_scopes+ a document naming a scope this server
          # does not know fails the model validation, and the client is
          # rejected outright rather than silently granted something else.
          application.scopes = document.scope.to_s

          application.save ? application : nil
        end
      rescue StandardError => e
        # Two concurrent resolutions raced on the uid unique index; the row
        # now exists, so hand back what the winner persisted.
        return Doorkeeper.config.application_model.by_uid(document.client_id) if unique_violation?(e)

        # Any other rejection from the database means this document cannot be
        # materialized — most plainly a value too long for its column, since
        # the generated migration declares name and scopes as +t.string+ (255
        # characters on MySQL). The document is supplied by whoever hosts the
        # client_id URL, so that has to fail the client lookup rather than
        # escape the endpoint as a 500.
        raise unless statement_invalid?(e)

        nil
      end

      # Named rather than rescued directly so this file stays usable with the
      # non-ActiveRecord ORM extensions: a bare `rescue ActiveRecord::...`
      # clause resolves the constant whenever any error passes through it.
      def self.unique_violation?(error)
        defined?(::ActiveRecord::RecordNotUnique) && error.is_a?(::ActiveRecord::RecordNotUnique)
      end
      private_class_method :unique_violation?

      # Checked after unique_violation? — RecordNotUnique is itself a
      # StatementInvalid, and the two are handled differently.
      def self.statement_invalid?(error)
        defined?(::ActiveRecord::StatementInvalid) && error.is_a?(::ActiveRecord::StatementInvalid)
      end
      private_class_method :statement_invalid?
    end
  end
end
