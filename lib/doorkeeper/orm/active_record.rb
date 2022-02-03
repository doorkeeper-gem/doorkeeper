# frozen_string_literal: true

module Doorkeeper
  autoload :AccessGrant, "doorkeeper/orm/active_record/access_grant"
  autoload :AccessToken, "doorkeeper/orm/active_record/access_token"
  autoload :Application, "doorkeeper/orm/active_record/application"
  autoload :RedirectUriValidator, "doorkeeper/orm/active_record/redirect_uri_validator"

  module Models
    autoload :Ownership, "doorkeeper/models/concerns/ownership"
  end

  # ActiveRecord ORM for Doorkeeper entity models.
  # Consists of three main OAuth entities:
  #   * Access Token
  #   * Access Grant
  #   * Application (client)
  #
  # Do a lazy loading of all the required and configured stuff.
  #
  module Orm
    module ActiveRecord
      autoload :StaleRecordsCleaner, "doorkeeper/orm/active_record/stale_records_cleaner"

      module Mixins
        autoload :AccessGrant, "doorkeeper/orm/active_record/mixins/access_grant"
        autoload :AccessToken, "doorkeeper/orm/active_record/mixins/access_token"
        autoload :Application, "doorkeeper/orm/active_record/mixins/application"
      end

      def self.run_hooks
        # Deprecated, will be removed soon
        return unless (options = Doorkeeper.config.active_record_options[:establish_connection])

        Doorkeeper::Orm::ActiveRecord.models.each do |model|
          model.establish_connection(options)
        end
      end

      def self.models
        [
          Doorkeeper.config.access_grant_model,
          Doorkeeper.config.access_token_model,
          Doorkeeper.config.application_model,
        ]
      end
    end
  end
end
