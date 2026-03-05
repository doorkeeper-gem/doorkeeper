# frozen_string_literal: true

module Doorkeeper
  module Orm
    module ActiveRecord
      # Helper class to clear stale and non-active tokens and grants.
      # Used by Doorkeeper Rake tasks.
      #
      class StaleRecordsCleaner
        def initialize(base_scope)
          @base_scope = base_scope
        end

        # Clears revoked records
        def clean_revoked
          table = @base_scope.arel_table

          @base_scope
            .where.not(revoked_at: nil)
            .where(table[:revoked_at].lt(Time.current))
            .in_batches(&:delete_all)
        end

        # Clears expired records
        def clean_expired(ttl)
          table = @base_scope.arel_table
          model_class = @base_scope.is_a?(::ActiveRecord::Relation) ? @base_scope.klass : @base_scope

          scope = @base_scope
            .where.not(expires_in: nil)
            .where(table[:created_at].lt(Time.current - ttl))

          if model_class.respond_to?(:supports_expiration_time_math?) && model_class.supports_expiration_time_math?
            scope = scope.where("#{model_class.expiration_time_sql} < ?", Time.current)
          else
            ::Kernel.warn <<~WARNING.squish
              [DOORKEEPER] Doorkeeper doesn't support expiration time math for your database adapter.
              Records with an individual expires_in value longer than the global TTL may be incorrectly removed.
              Please add a class method `custom_expiration_time_sql` to your model to provide a custom
              SQL expression for calculating expiration time.
            WARNING
          end

          scope.in_batches(&:delete_all)
        end
      end
    end
  end
end
