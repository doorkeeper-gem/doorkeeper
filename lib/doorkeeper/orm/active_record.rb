# frozen_string_literal: true

require "active_support/lazy_load_hooks"

module Doorkeeper
  module Orm
    # ActiveRecord ORM for Doorkeeper entity models.
    # Consists of three main OAuth entities:
    #   * Access Token
    #   * Access Grant
    #   * Application (client)
    #
    # Do a lazy loading of all the required and configured stuff.
    #
    module ActiveRecord
      def self.initialize_models!
        lazy_load do
          require "doorkeeper/orm/active_record/stale_records_cleaner"
          require "doorkeeper/orm/active_record/access_grant"
          require "doorkeeper/orm/active_record/access_token"
          require "doorkeeper/orm/active_record/application"

          if Doorkeeper.configuration.active_record_options[:establish_connection]
            Doorkeeper::Orm::ActiveRecord.models.each do |model|
              options = Doorkeeper.configuration.active_record_options[:establish_connection]
              model.establish_connection(options)
            end
          end
        end
      end

      def self.initialize_application_owner!
        lazy_load do
          require "doorkeeper/models/concerns/ownership"

          Doorkeeper::Application.send :include, Doorkeeper::Models::Ownership
        end
      end

      def self.lazy_load(&block)
        ActiveSupport.on_load(:active_record, {}, &block)
      end

      def self.models
        [
          Doorkeeper::AccessGrant,
          Doorkeeper::AccessToken,
          Doorkeeper::Application,
        ]
      end
    end
  end
end
