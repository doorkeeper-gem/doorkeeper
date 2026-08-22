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
      #
      # Only the application-model contract is used (+by_uid+, +new+, the
      # attribute writers, +valid?+, +save+), never an ActiveRecord-only
      # finder, so the feature works with the ORM extensions that implement
      # that contract.
      def self.upsert(document)
        model = Doorkeeper.config.application_model

        on_primary(model) do
          application = model.by_uid(document.client_id) || model.new(uid: document.client_id)
          # The draft compares client_ids as strings (Section 3), but the
          # lookup above delegates that comparison to the database: MySQL's
          # default collation is case-insensitive, so a row whose uid differs
          # only in case would be adopted here and have another client's
          # attributes written over it. A row that is not this client's is no
          # row at all.
          return nil unless application.uid == document.client_id

          apply(document, application)

          # Asked before saving because the ORMs differ on what a failed save
          # does: ActiveRecord returns false, Sequel raises by default. Either
          # way an invalid row is this document's fault and fails the client.
          return nil if application.respond_to?(:valid?) && !application.valid?

          application.save ? application : nil
        end
      rescue StandardError => e
        # Two concurrent resolutions raced on the uid unique index; the row
        # now exists, so hand back what the winner persisted. The read is
        # pinned to the primary as well: the winner committed only a moment
        # ago, so a replica routed by automatic role switching may not have
        # the row yet, and missing it would fail a valid client.
        return race_winner(model, document) if unique_violation?(e)

        # A value too long for its column is the one database rejection this
        # document could have caused: the generated migration declares name
        # and scopes as +t.string+, 255 characters on MySQL. It is supplied by
        # whoever hosts the client_id URL, so it has to fail the client lookup
        # rather than escape the endpoint as a 500. Every other statement
        # failure — a deadlock, a cancelled query, a schema mismatch — is the
        # deployment's problem, not this client's, and must not be disguised
        # as invalid_client where nothing would ever surface it.
        raise unless value_too_long?(e)

        nil
      end

      def self.apply(document, application)
        application.name = document.client_name.presence || URI.parse(document.client_id).host
        application.redirect_uri = document.redirect_uris
        application.confidential = document.confidential?
        # Assigned even when the document omits it, so dropping the property
        # widens the client back to the server's default scopes instead of
        # leaving a stale restriction behind. The document itself may only
        # name scopes this server configured (Document#validate_scope!), so
        # what lands here is never wider than the server's own list.
        application.scopes = document.scope.to_s
        ensure_secret(application)
      end
      private_class_method :apply

      # Subject to the same byte-for-byte uid check as the row the factory
      # would have created: the unique index that reported the race is the
      # database's, whose collation need not be case-sensitive, so the winner
      # may be a different client_id that only looks equal.
      def self.race_winner(model, document)
        application = on_primary(model) { model.by_uid(document.client_id) }

        application if application&.uid == document.client_id
      end
      private_class_method :race_winner

      # Guarded the way Doorkeeper's other mid-request writes guard it: the
      # role switch is an ActiveRecord affordance, and a model from another
      # ORM extension need not offer it.
      def self.on_primary(model, &block)
        return yield unless model.respond_to?(:with_primary_role)

        model.with_primary_role(&block)
      end
      private_class_method :on_primary

      # A document that changes its auth method from "none" turns a public row
      # confidential, and the model then requires a secret it only generates on
      # create. Without this a deployment whose secret column is nullable
      # (which is how the generated migration says to support public clients)
      # would fail the client for good. Guarded by respond_to? for the same
      # reason unique_violation? is named below: an ORM extension need not
      # provide every ActiveRecord affordance.
      def self.ensure_secret(application)
        return unless application.confidential && application.secret.blank?

        application.renew_secret if application.respond_to?(:renew_secret)
      end
      private_class_method :ensure_secret

      # Named rather than rescued directly so this file stays usable with the
      # non-ActiveRecord ORM extensions: a bare `rescue ActiveRecord::...`
      # clause resolves the constant whenever any error passes through it.
      def self.unique_violation?(error)
        defined?(::ActiveRecord::RecordNotUnique) && error.is_a?(::ActiveRecord::RecordNotUnique)
      end
      private_class_method :unique_violation?

      # Named for the same reason as unique_violation?. Deliberately narrower
      # than StatementInvalid, which also covers Deadlocked, LockWaitTimeout,
      # QueryCanceled and SerializationFailure — operational failures that
      # have nothing to do with the document and are usually retryable.
      def self.value_too_long?(error)
        defined?(::ActiveRecord::ValueTooLong) && error.is_a?(::ActiveRecord::ValueTooLong)
      end
      private_class_method :value_too_long?
    end
  end
end
