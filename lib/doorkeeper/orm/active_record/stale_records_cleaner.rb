# frozen_string_literal: true

module Doorkeeper
  module Orm
    module ActiveRecord
      class StaleRecordsCleaner
        def initialize(model)
          @model = model
        end

        def clean_revoked
          table = @model.arel_table
          @model.where.not(revoked_at: nil)
                .where(table[:revoked_at].lt(Time.current))
                .delete_all
        end

        def clean_expired(ttl)
          table = @model.arel_table
          @model.where(table[:created_at].lt(Time.current - ttl))
                .delete_all
        end
      end
    end
  end
end
