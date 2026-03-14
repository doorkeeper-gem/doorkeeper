# frozen_string_literal: true

module Doorkeeper
  module Orm
    module ActiveRecord
      module Mixins
        module Expirable
          extend ActiveSupport::Concern

          included do
            include ::Doorkeeper::Models::ExpirationTimeSqlMath

            scope :expires, -> { where.not(expires_in: nil) }
            scope :expired, lambda {
              if supports_expiration_time_math?
                expires.where("#{expiration_time_sql} < ?", Time.current)
              else
                ::Kernel.warn <<~WARNING.squish
                  [DOORKEEPER] Doorkeeper doesn't support expiration time math for your database adapter (#{adapter_name}).
                  Please add a class method `custom_expiration_time_sql` for your #{name} class/mixin to provide a custom
                  SQL expression to calculate token expiration time. See
                  lib/doorkeeper/models/concerns/expiration_time_sql_math.rb for more details.
                WARNING

                expires
              end
            }
          end
        end
      end
    end
  end
end
