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
      # attribute writers, +valid?+, +save+, and the
      # +client_id_metadata_materialized_at+ attribute the host's migration
      # adds), never an ActiveRecord-only finder, so the feature works with
      # the ORM extensions that implement that contract.
      def self.upsert(document)
        model = Doorkeeper.config.application_model
        # Assigned inside the block but read by the rescue below, which
        # recovers a lost race only where one is possible.
        existing = nil

        on_primary(model) do
          existing = model.by_uid(document.client_id)
          application = existing || build(model, document.client_id)
          # The draft compares client_ids as strings (Section 3), but the
          # lookup above delegates that comparison to the database: MySQL's
          # default collation is case-insensitive, so a row whose uid differs
          # only in case would be adopted here and have another client's
          # attributes written over it. A row that is not this client's is no
          # row at all.
          return nil unless application.uid == document.client_id
          return nil unless from_metadata_document?(application, existing)

          apply(document, application)

          # Asked before saving because the ORMs differ on what a failed save
          # does: ActiveRecord returns false, Sequel raises by default. Either
          # way an invalid row is this document's fault and fails the client —
          # unless what failed is the uid's own uniqueness: the lookup above
          # found no row, so a validation that now sees one lost the same race
          # the rescue below recovers, only earlier, at the validation's
          # SELECT instead of at the insert. Handing back what the winner
          # persisted keeps genuine validation failures failing: with no
          # winner there is nothing to hand back.
          return invalid_row_outcome(model, document, application, existing) if invalid_row?(application)
          return application if persisted_and_unchanged?(application)

          outcome = save_row(model, application, existing)
          return application if outcome
          # The row stopped being this document's while the document was
          # being applied to it — see save_row. Not a validation failure, so
          # there is no race winner to recover through and nothing about the
          # document to log: the client is simply refused, as it will be on
          # every resolution from now on.
          return nil if outcome.nil?

          # ActiveRecord validates again inside save, so the same race can be
          # observed one SELECT later still: save answers false, and no
          # insert was ever attempted. Same race, same recovery — and, as
          # above, nothing to hand back when the failure is genuine. Sequel
          # raises here instead, which the rescue below recognizes.
          invalid_row_outcome(model, document, application, existing)
        end
      rescue StandardError => e
        recover_from(e, model, document, existing)
      end

      # Two concurrent resolutions raced on the uid unique index; the row
      # now exists, so hand back what the winner persisted. The read is
      # pinned to the primary as well: the winner committed only a moment
      # ago, so a replica routed by automatic role switching may not have
      # the row yet, and missing it would fail a valid client. Only a
      # creation can have lost that race, though: the row an update writes
      # already holds the uid, so a unique index tripped mid-update is
      # another, host-added one (a unique name, say) that this document's
      # values ran into — recovering through the winner would report success
      # with the very metadata the database just refused. That rejection is
      # the document's doing and fails the client, like the over-long value
      # below.
      #
      # A value too long for its column is the other database rejection this
      # document could have caused: the generated migration declares name
      # and scopes as +t.string+, 255 characters on MySQL. It is supplied by
      # whoever hosts the client_id URL, so it has to fail the client lookup
      # rather than escape the endpoint as a 500. Every other statement
      # failure — a deadlock, a cancelled query, a schema mismatch — is the
      # deployment's problem, not this client's, and must not be disguised
      # as invalid_client where nothing would ever surface it.
      #
      # Sequel's save validates again and raises on failure where
      # ActiveRecord's answers false, so a row that passed valid? a moment
      # earlier and fails inside save reports the uniqueness race that way;
      # it is treated like the unique index it would otherwise have gone on
      # to trip.
      def self.recover_from(error, model, document, existing)
        if unique_violation?(error) || validation_failed?(error)
          return existing.nil? ? race_winner(model, document) : nil
        end

        raise error unless value_rejected_by_column?(error)

        nil
      end
      private_class_method :recover_from

      # ActiveRecord and Mongoid answer #changed?; Sequel answers #modified?
      # and, unlike either, writes every column on #save rather than only the
      # ones that moved. An unchanged row must therefore not reach #save at
      # all: resolution runs on unauthenticated traffic, so a full UPDATE per
      # request would have concurrent resolutions of one popular document
      # client serialize on its row.
      def self.persisted_and_unchanged?(application)
        return false if application.respond_to?(:new_record?) && application.new_record?
        return false if application.respond_to?(:new?) && application.new?
        return !application.changed? if application.respond_to?(:changed?)
        return !application.modified? if application.respond_to?(:modified?)

        false
      end
      private_class_method :persisted_and_unchanged?

      def self.apply(document, application)
        # Stamped on first materialization only, so an unchanged document
        # stays a no-op write — see persisted_and_unchanged?, which is what
        # keeps it one; the stamp is what from_metadata_document?
        # reads back on later resolutions.
        application.client_id_metadata_materialized_at ||= Time.now.utc
        application.name = document.client_name.presence || URI.parse(document.client_id).host
        # Joined here rather than left to the model's writer: only
        # ActiveRecord's application mixin turns an Array into the
        # newline-separated column value (ApplicationMixin#redirect_uri=), and
        # the Sequel extension's mixin does not define that writer at all, so
        # an Array would reach the column as one.
        application.redirect_uri = document.redirect_uris.join("\n")
        application.confidential = document.confidential?
        # Assigned even when the document omits it, so dropping the property
        # removes the client's own allow-list instead of leaving a stale
        # restriction behind. What that leaves is not the server's *default*
        # scopes: ScopeChecker reads an application's scopes as the allow-list
        # in place of the server's (+app_scopes.presence || server_scopes+),
        # so a blank column is every scope this server configures,
        # optional_scopes included. The document itself may only name scopes
        # this server configured (Document#validate_scope!), so what lands
        # here is never wider than that list either way.
        application.scopes = document.scope.to_s
        ensure_secret(application)
      end
      private_class_method :apply

      # The uid goes through its writer rather than +new+'s attribute hash:
      # the Sequel extension's application mixin restricts mass assignment to
      # the user-editable columns (set_allowed_columns), so `new(uid: ...)`
      # raises there. Assigned before validation, the extensions' own
      # generate-a-uid hooks all leave it alone — they only fill a blank uid.
      def self.build(model, client_id)
        application = model.new
        application.uid = client_id
        application
      end
      private_class_method :build

      def self.invalid_row?(application)
        application.respond_to?(:valid?) && !application.valid?
      end
      private_class_method :invalid_row?

      # The insert can lose the uid race and trip the unique index, which the
      # rescue above recovers from by reading the winner back — on every ORM,
      # each of whose duplicate-key errors recover_from recognizes. What is
      # Active Record's alone is surviving that race *inside a transaction the
      # caller opened*: PostgreSQL refuses every later statement on a
      # transaction one of whose statements failed, so the recovering read
      # would fail too and a survivable race would surface as a 500. A
      # savepoint confines the failed insert to itself and leaves the caller's
      # transaction usable.
      #
      # Active Record is the only ORM here that offers one under this name:
      # Mongoid answers #transaction as well, but raises unless the deployment
      # runs a replica set, and Sequel spells a savepoint on its database
      # object instead (`model.db.transaction(savepoint: true)`). Both keep
      # the plain save they had, so on those a lost race inside a caller's
      # transaction behaves exactly as it did before this feature — which is
      # the scope of the guarantee, not an omission from it. Extending it
      # would mean exercising it against those adapters, which live in gems
      # of their own.
      #
      # The provenance the row was admitted on is confirmed inside that
      # transaction, with the row locked: between the lookup above and this
      # write an operator can clear the stamp to adopt the row as a registered
      # application, which is what the generated initializer documents as the
      # way to keep such a client for good. The stamp is unchanged in this
      # object, so Active Record would not write it back — the document's
      # name, redirect URIs, scopes and confidentiality would land on a row
      # that no later check would refuse, and this method would hand back an
      # object still claiming a provenance the row no longer has.
      #
      # @return [Boolean, nil] what the save answered, or nil when the row was
      #   no longer this document's to write
      def self.save_row(model, application, existing)
        return application.save unless active_record_model?(model)

        model.transaction(requires_new: true) do
          next nil unless provenance_held?(model, existing)

          application.save
        end
      end
      private_class_method :save_row

      # Whether the row is still stamped as this feature's, read from the
      # database rather than off the object that could be stale, and without
      # reloading it — a reload would discard everything apply just assigned.
      # The lock is what makes the answer good for the length of the
      # transaction: an operator clearing the stamp either committed before
      # this read, and is seen, or waits for the write to commit and takes
      # effect from the next resolution on. Nothing to hold for a creation:
      # there is no row yet to change under us, and the insert's own unique
      # index is what decides that race (see recover_from).
      def self.provenance_held?(model, existing)
        return true if existing.nil?

        locked = model.lock(true).where(model.primary_key => existing.public_send(model.primary_key))

        locked.pick(:client_id_metadata_materialized_at).present?
      end
      private_class_method :provenance_held?

      def self.active_record_model?(model)
        defined?(::ActiveRecord::Base) && model.is_a?(Class) && model <= ::ActiveRecord::Base
      end
      private_class_method :active_record_model?

      # What an invalid row comes to: the winner of the uid race when a
      # creation lost one (see upsert), and otherwise a refusal, logged.
      def self.invalid_row_outcome(model, document, application, existing)
        winner = existing.nil? ? race_winner(model, document) : nil
        log_invalid_row(document, application) unless winner
        winner
      end
      private_class_method :invalid_row_outcome

      # The other two refusals in this file explain themselves in the log;
      # this one must too, or a document that fails the model's validation —
      # an http:// redirect URI under force_ssl_in_redirect_uri, a
      # host-added validation the row runs into — is indistinguishable, from
      # the outside, from a malformed one: both answer invalid_client.
      def self.log_invalid_row(document, application)
        errors = application.errors if application.respond_to?(:errors)
        details = errors.respond_to?(:full_messages) ? errors.full_messages.join(", ") : errors.inspect

        ::Rails.logger.warn(
          "[DOORKEEPER] Refusing to materialize #{document.client_id.inspect} from its Client ID " \
          "Metadata Document: the application row fails validation (#{details}).",
        )
      end
      private_class_method :log_invalid_row

      # Adopting a row is what turns a URL into this client, so the row must
      # demonstrably be this feature's: +client_id_metadata_materialized_at+
      # records that the factory itself materialized it from a fetched
      # document. The https:// prefix alone cannot make that distinction
      # (draft Section 7.1): Doorkeeper's generated uids never start with it,
      # but a host application may well have given registered applications
      # URL-shaped uids — vanity identifiers, or Client Identifier URLs
      # pre-registered as Section 7.2 permits — and refreshing such a row
      # from whatever its URL serves would hand the row, with every grant
      # and token still attached to it, to whoever controls the URL. Callers
      # route such a uid to the registered application before fetching
      # (ClientIdMetadata.resolves_through_document?); this check catches
      # the row that appeared in between, and direct callers of resolve.
      def self.from_metadata_document?(application, existing)
        unless application.respond_to?(:client_id_metadata_materialized_at)
          ::Rails.logger.warn(
            "[DOORKEEPER] use_client_id_metadata_documents requires a " \
            "client_id_metadata_materialized_at datetime column on the applications table to " \
            "tell the rows it materializes apart from registered applications; the attribute " \
            "is missing, so every Client ID Metadata Document client is refused as " \
            "invalid_client. See the option's notes in the initializer for the migration.",
          )
          return false
        end

        return true if existing.nil? || existing.client_id_metadata_materialized_at.present?

        ::Rails.logger.warn(
          "[DOORKEEPER] Refusing to materialize #{existing.uid.inspect} from its Client ID " \
          "Metadata Document: a registered application holds that uid " \
          "(client_id_metadata_materialized_at is blank, so the row was not materialized by " \
          "this feature), and the URL resolves as that application instead. Delete it if the " \
          "URL is meant to resolve as a metadata document.",
        )
        false
      end
      private_class_method :from_metadata_document?

      # Subject to the same byte-for-byte uid check as the row the factory
      # would have created: the unique index that reported the race is the
      # database's, whose collation need not be case-sensitive, so the winner
      # may be a different client_id that only looks equal. And subject to
      # the same provenance check: the insert can lose not only to a
      # concurrent resolution but to an administrator registering the same
      # uid by hand, and that winner is a registered application, not this
      # feature's row.
      def self.race_winner(model, document)
        application = on_primary(model) { model.by_uid(document.client_id) }
        return unless application&.uid == document.client_id

        application if application.client_id_metadata_materialized_at.present?
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
      # Each supported extension reports the lost race in its own way, and
      # missing one would turn a survivable race into a 500, so all three are
      # recognized here.
      def self.unique_violation?(error)
        return true if defined?(::ActiveRecord::RecordNotUnique) && error.is_a?(::ActiveRecord::RecordNotUnique)
        return true if defined?(::Sequel::UniqueConstraintViolation) && error.is_a?(::Sequel::UniqueConstraintViolation)

        mongo_duplicate_key?(error)
      end
      private_class_method :unique_violation?

      # The Mongo driver has no dedicated class for it: the server reports a
      # duplicate key as an OperationFailure whose code is 11000 (11001 from
      # older servers). The message is consulted as well because wrapped or
      # legacy failures do not always carry the code, while every duplicate-key
      # message the server ever produced names E11000.
      def self.mongo_duplicate_key?(error)
        return false unless defined?(::Mongo::Error::OperationFailure) && error.is_a?(::Mongo::Error::OperationFailure)

        (error.respond_to?(:code) && [11_000, 11_001].include?(error.code)) ||
          error.message.include?("E11000")
      end
      private_class_method :mongo_duplicate_key?

      # Named for the same reason as unique_violation?.
      def self.validation_failed?(error)
        defined?(::Sequel::ValidationFailed) && error.is_a?(::Sequel::ValidationFailed)
      end
      private_class_method :validation_failed?

      # Named for the same reason as unique_violation?. Deliberately narrower
      # than StatementInvalid, which also covers Deadlocked, LockWaitTimeout,
      # QueryCanceled and SerializationFailure — operational failures that
      # have nothing to do with the document and are usually retryable.
      #
      # A value the column's charset cannot store is the document's doing
      # exactly as an over-long one is: MySQL answers 1366 for a 4-byte
      # character written to a legacy `utf8` column, which Rails leaves a bare
      # StatementInvalid (only 1406 becomes ValueTooLong). Left to the raise
      # above, a client_name carrying an emoji would be a 500 at the
      # unauthenticated authorization endpoint rather than a refused client.
      def self.value_rejected_by_column?(error)
        return true if defined?(::ActiveRecord::ValueTooLong) && error.is_a?(::ActiveRecord::ValueTooLong)

        defined?(::ActiveRecord::StatementInvalid) &&
          error.is_a?(::ActiveRecord::StatementInvalid) &&
          error.message.include?("Incorrect string value")
      end
      private_class_method :value_rejected_by_column?
    end
  end
end
