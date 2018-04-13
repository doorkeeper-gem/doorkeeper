# frozen_string_literal: true

module Doorkeeper
  module Orm
    module ActiveRecord
      class StaleRecordsCleaner
        def initialize(base_scope)
          @base_scope = base_scope
        end

        def clean_revoked
          table = @base_scope.arel_table
          @base_scope.where.not(revoked_at: nil)
                     .where(table[:revoked_at].lt(Time.current))
                     .delete_all
        end

        def clean_expired(ttl)
          table = @base_scope.arel_table
          @base_scope.where(table[:created_at].lt(Time.current - ttl))
                     .delete_all
        end
      end
    end
  end
end
