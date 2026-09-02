# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  # Active Record implementation of the SecretStorable write hook: the
  # fallback secret upgrade only writes while the column still holds the
  # value the lookup matched, so losing a race against a concurrent write —
  # another request renewing the secret, or the application replacing it —
  # cannot put the superseded secret back.
  #
  # The write is a single conditional statement, so unlike the historical
  # `#update` it runs no model callbacks: what it writes is the value the
  # lookup already matched, re-encoded into the current storage format.
  module SecretStorable
    extend ActiveSupport::Concern

    class_methods do
      # Writes the upgraded secret over +matched+ on +instance+'s row,
      # conditional on +attr+ still holding +matched+, and answers whether
      # the row was written.
      def write_upgraded_secret(instance, attr, matched, _upgraded)
        # The value written is the one `store_secret` left on the instance:
        # it assigns through the attribute writer, which `#update` then ran
        # again on assignment, so a custom writer override reached storage.
        # `update_all` does not go through writers, so writing the strategy's
        # pre-writer return value would both skip the override and leave the
        # instance out of step with its row.
        upgraded = instance.read_attribute(attr)

        # `update_all` does not maintain timestamps, which `#update` did —
        # see `upgrade_timestamps` for the terms it did that on.
        changes = { attr => upgraded }.merge!(upgrade_timestamps(instance))

        scope = where(primary_key_conditions(instance).merge(attr => matched))

        # Under optimistic locking, `update_all` bumps the lock column on
        # its own, which would leave the instance stale and have its next
        # `save` refused. Write the bump explicitly instead — `update_all`
        # leaves the column alone when it is among the changes — so that the
        # instance can be brought in step below, and make the write
        # conditional on the version too: bumping from a version the row no
        # longer holds would set it backwards.
        if locking_enabled?
          version = instance.public_send(locking_column) || 0
          scope = scope.where(locking_column => version)
          changes[locking_column] = version + 1
        end

        # The write must reach the primary database when automatic role
        # switching would route the surrounding request to a read replica.
        written = with_primary_role { scope.update_all(changes) }
        return false if written.zero?

        sync_upgraded_instance(instance, changes)
        true
      end

      # Restores +matched+ on the attribute directly, past any custom
      # writer: re-running a writer that transforms its input would leave
      # the attribute dirty with a value the row never held, and a later
      # save would write that over whatever replaced the matched secret.
      # The change is then cleared — the attribute holds what it held when
      # the row was read, so there is nothing left to save.
      def restore_matched_secret(instance, attr, matched)
        instance.write_attribute(attr, matched)
        instance.clear_attribute_changes([attr])
      end

      private

      # The columns identifying +instance+'s row and the values it holds in
      # them, taken from the configured primary key: it may be named
      # something other than `id`, or be composed of several columns. A
      # model with no primary key at all is left to the value condition
      # alone, which reaches every row still holding the matched secret.
      def primary_key_conditions(instance)
        # Spelled without `index_with`, which the gemspec's Rails floor
        # predates.
        Array(primary_key).to_h { |key| [key, instance.public_send(key)] } # rubocop:disable Rails/IndexWith
      end

      # The timestamps `#update` maintained for this write, derived on its
      # terms through Active Record's own helpers: the model's actual update
      # timestamp columns (`updated_on` and aliased names as well as
      # `updated_at`), the connection's timezone, and `record_timestamps`
      # read on the instance, where a model that stamps its own timestamps
      # can turn it off per record. A timestamp the caller had already
      # changed is left out entirely, as `#update` leaves it to the caller —
      # stamping it and then marking it clean below would silently drop that
      # pending change.
      def upgrade_timestamps(instance)
        return {} unless instance.record_timestamps

        touch_attributes_with_time.reject do |column, _time|
          instance.will_save_change_to_attribute?(column)
        end
      end

      # The row was written past the instance, so bring it back in step:
      # left as it is, a caller that later saves or locks the record is
      # refused over a change that is already persisted. Only what was
      # written is marked clean — a `reload` would also discard every
      # unrelated unsaved change the caller had on the instance, and this is
      # nominally a read path.
      def sync_upgraded_instance(instance, changes)
        timestamp_attributes_for_update_in_model.each do |column|
          instance.public_send(:"#{column}=", changes[column]) if changes.key?(column)
        end
        instance.public_send(:"#{locking_column}=", changes[locking_column]) if locking_enabled?
        instance.clear_attribute_changes(changes.keys)
      end
    end
  end
end
