# frozen_string_literal: true

module Doorkeeper
  module Models
    module Concerns
      # Provides support for Rails read replicas by ensuring write operations
      # use the primary database when automatic role switching is enabled.
      #
      # When Rails uses automatic role switching with read replicas, GET requests
      # are routed to read-only databases. However, Doorkeeper may need to write
      # to the database during GET requests (e.g., creating access tokens during
      # implicit grant flow). This concern wraps write operations with
      # `connected_to(role: :writing)` to ensure they use the primary database.
      #
      # This concern is only active when:
      # 1. ActiveRecord supports `connected_to` (Rails 6.1+)
      # 2. The configuration option is enabled
      #
      module WriteToPrimary
        extend ActiveSupport::Concern

        class_methods do
          # Executes the given block with a connection to the primary database
          # for writing, if read replica support is enabled and available.
          #
          # @yield Block to execute with write connection
          # @return The result of the block
          #
          def with_primary_role(&block)
            if should_use_primary_role?
              ::ActiveRecord::Base.connected_to(role: :writing, &block)
            else
              yield
            end
          end

          private

          # Determines if we should explicitly use the primary role for writes
          #
          # @return [Boolean]
          #
          def should_use_primary_role?
            # Guard clause: return false if ActiveRecord is not available
            return false unless defined?(::ActiveRecord::Base)

            # Only use primary role if:
            # 1. The enable_multiple_databases option is enabled in config
            # 2. ActiveRecord supports connected_to (Rails 6.1+)
            Doorkeeper.config.enable_multiple_databases &&
              ::ActiveRecord::Base.respond_to?(:connected_to)
          end
        end
      end
    end
  end
end
