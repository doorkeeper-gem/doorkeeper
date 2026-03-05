# frozen_string_literal: true

module Doorkeeper::Orm::ActiveRecord::Mixins
  module Expirable
    extend ActiveSupport::Concern

    included do
      scope :expires, -> { where.not(expires_in: nil) }
      scope :expired, lambda {
        time = Time.current

        scope = case connection.adapter_name
                when 'PostgreSQL', "PostGIS"
                  where("created_at + expires_in * INTERVAL '1 second' < ?", time)
                when 'Mysql2', 'Trilogy'
                  where("DATE_ADD(created_at, INTERVAL expires_in SECOND) < ?", time)
                when 'SQLite'
                  where("datetime(created_at, '+' || expires_in || ' seconds') < ?", time)
                else
                  raise NotImplementedError, "#{self}.#{__method__} not supported for database connection adapter #{connection.adapter_name.inspect}"
                end

        where(expires_in: nil).or(scope)
      }
    end
  end
end
