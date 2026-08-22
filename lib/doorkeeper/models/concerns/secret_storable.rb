# frozen_string_literal: true

module Doorkeeper
  module Models
    ##
    # Storable finder to provide lookups for input plaintext values which are
    # mapped to their stored versions (e.g., hashing, encryption) before lookup.
    module SecretStorable
      extend ActiveSupport::Concern

      delegate :secret_strategy,
               :fallback_secret_strategy,
               to: :class

      # :nodoc
      module ClassMethods
        # Compare the given plaintext with the secret
        #
        # @param input [String]
        #   The plain input to compare.
        #
        # @param secret [String]
        #   The secret value to compare with.
        #
        # @return [Boolean]
        #   Whether input matches secret as per the secret strategy
        #
        delegate :secret_matches?, to: :secret_strategy

        # Returns an instance of the Doorkeeper::AccessToken with
        # specific token value.
        #
        # @param attr [Symbol]
        #   The token attribute we're looking with.
        #
        # @param token [#to_s]
        #   token value (any object that responds to `#to_s`)
        #
        # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
        #   if there is no record with such token
        #
        def find_by_plaintext_token(attr, token)
          token = token.to_s

          find_by(attr => secret_strategy.transform_secret(token)) ||
            find_by_fallback_token(attr, token)
        end

        # Allow looking up previously plain tokens as a fallback
        # IFF a fallback strategy has been defined
        #
        # @param attr [Symbol]
        #   The token attribute we're looking with.
        #
        # @param plain_secret [#to_s]
        #   plain secret value (any object that responds to `#to_s`)
        #
        # @return [Doorkeeper::AccessToken, nil] AccessToken object or nil
        #   if there is no record with such token
        #
        def find_by_fallback_token(attr, plain_secret)
          return nil unless fallback_secret_strategy

          # Use the previous strategy to look up
          stored_token = fallback_secret_strategy.transform_secret(plain_secret)
          find_by(attr => stored_token).tap do |resource|
            return nil unless resource

            upgrade_fallback_value resource, attr, plain_secret
          end
        end

        # Allow implementations in ORMs to replace a plain
        # value falling back to to avoid it remaining as plain text.
        #
        # @param instance
        #   An instance of this model with a plain value token.
        #
        # @param attr
        #   The secret attribute name to upgrade.
        #
        # @param plain_secret
        #   The plain secret to upgrade.
        #
        # @return [Boolean]
        #   Whether the stored value was upgraded. False means the row no
        #   longer holds the value that was matched.
        #
        def upgrade_fallback_value(instance, attr, plain_secret)
          # The value the fallback strategy matched against. The upgrade is a
          # write on what is otherwise a read path, so the row can move between
          # the match and this write — another request renewing the secret, or
          # the application replacing it. Writing by id alone would put the
          # matched value back over whatever replaced it, so the write is
          # conditional on the column still holding it.
          matched = instance.public_send(attr)
          upgraded = secret_strategy.store_secret(instance, attr, plain_secret)

          changes = { attr => upgraded }
          # `update_all` does not maintain timestamps, which `#update` did.
          changes[:updated_at] = Time.now.utc if stamps_updated_at?(instance)

          scope = matched_row_scope(instance, attr, matched)

          # Under optimistic locking, `update_all` bumps the lock column on
          # its own, which would leave the instance stale and have its next
          # `save` refused. Write the bump explicitly instead — `update_all`
          # leaves the column alone when it is among the changes — so that the
          # instance can be brought in step below, and make the write
          # conditional on the version too: bumping from a version the row no
          # longer holds would set it backwards.
          if optimistic_locking?
            version = instance.public_send(locking_column) || 0
            scope = scope.where(locking_column => version)
            changes[locking_column] = version + 1
          end

          # The write must reach the primary database when automatic role
          # switching would route the surrounding request to a read replica.
          written =
            if respond_to?(:with_primary_role)
              with_primary_role { update_matched_rows(scope, changes) }
            else
              update_matched_rows(scope, changes)
            end

          if written.zero?
            # Nothing was written. `store_secret` has already assigned the
            # upgraded value in memory, so put the instance back rather than
            # leave it carrying a secret that was never stored — and withdraw
            # the assignment from the ORMs that record one having been made.
            instance.public_send(:"#{attr}=", matched)
            forget_assigned_columns(instance, [attr])
            return false
          end

          sync_upgraded_instance(instance, changes)
          true
        end

        # The row that held +matched+ in +attr+, identified by the model's
        # configured primary key rather than a hard-coded `id`.
        def matched_row_scope(instance, attr, matched)
          where(primary_key_conditions(instance).merge(attr => matched))
        end

        # The columns identifying +instance+'s row and the values it holds in
        # them, taken from the model's configured primary key: it may be named
        # something other than `id`, and Active Record answers with an array
        # of column names where the key is composed of several — passing that
        # array on as a single column name is a TypeError. An ORM with no
        # notion of a primary key has `id` as the fallback.
        def primary_key_conditions(instance)
          keys = respond_to?(:primary_key) && primary_key ? Array(primary_key) : [:id]

          keys.index_with { |key| instance.public_send(key) }
        end

        # Whether the upgrade stamps +updated_at+, which `#update` did for it
        # before the write became conditional — including its deference to
        # `record_timestamps`, which a model that stamps its own timestamps
        # turns off. An ORM that does not know the setting is taken to be
        # stamping, as it was.
        def stamps_updated_at?(instance)
          return false unless instance.respond_to?(:updated_at)

          !respond_to?(:record_timestamps) || record_timestamps
        end

        def optimistic_locking?
          respond_to?(:locking_enabled?) && locking_enabled?
        end

        # The row was written past the instance, so bring the dirty tracking
        # back in step: left as it is, a caller that later reloads or locks
        # the record is refused over a change that is already persisted. Only
        # what was written is marked clean — a `reload` would also discard
        # every unrelated unsaved change the caller had on the instance, and
        # this is nominally a read path.
        def sync_upgraded_instance(instance, changes)
          instance.updated_at = changes[:updated_at] if changes.key?(:updated_at)
          instance.public_send(:"#{locking_column}=", changes[locking_column]) if optimistic_locking?
          # Each ORM is told in its own terms; one with no dirty tracking at
          # all has nothing to correct here.
          instance.clear_attribute_changes(changes.keys) if instance.respond_to?(:clear_attribute_changes)
          forget_assigned_columns(instance, changes.keys)
        end

        # Withdraws +keys+ from the columns Sequel records as assigned since
        # the last save, which is what it decides `#modified?` and the columns
        # `#save_changes` writes from — and which it does not take a column
        # off when the value it held is assigned back.
        #
        # Active Record wants no equivalent: it decides dirtiness by comparing
        # against the values the row was loaded with, so an attribute put back
        # is clean again on its own, and clearing it there would forget a
        # change the caller had made to the same column before the lookup.
        def forget_assigned_columns(instance, keys)
          return unless instance.respond_to?(:changed_columns)

          columns = keys.map(&:to_sym)
          instance.changed_columns.reject! { |column| columns.include?(column) }
        end

        # Writes +changes+ to the rows +scope+ still matches and answers how
        # many there were. Spelled `update_all` by Active Record and Mongoid,
        # `update` by a Sequel dataset: this concern is included by the ORM
        # extensions too, and the value it decides on — whether the row still
        # held the value that was matched — is the same either way.
        def update_matched_rows(scope, changes)
          written =
            if scope.respond_to?(:update_all)
              scope.update_all(changes)
            else
              scope.update(changes)
            end

          matched_row_count(written)
        end

        # How many rows a write reached, however the ORM chose to answer it.
        # Active Record and Sequel answer with the count itself; Mongoid
        # answers with the driver's update result, which carries it as
        # +matched_count+ — and answers +false+ when it wrote nothing at all.
        # An ORM whose answer says neither is taken at its word, as it was
        # before the write became conditional.
        def matched_row_count(written)
          return written.matched_count if written.respond_to?(:matched_count)
          return written if written.respond_to?(:zero?)

          written ? 1 : 0
        end

        ##
        # Determines the secret storing transformer
        # Unless configured otherwise, uses the plain secret strategy
        def secret_strategy
          ::Doorkeeper::SecretStoring::Plain
        end

        ##
        # Determine the fallback storing strategy
        # Unless configured, there will be no fallback
        def fallback_secret_strategy
          nil
        end
      end
    end
  end
end
