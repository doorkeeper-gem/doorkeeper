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
        initialize_configured_associations
        # Force ActiveRecord::Base to load now so any pending
        # on_load(:active_record) callbacks (including the one just registered
        # above) fire in this safe context — typically `config.to_prepare`,
        # well after `:load_config_initializers`.
        #
        # Without this, a queued callback can fire re-entrantly during a host
        # app autoload chain (e.g. `rails db:seed` evaluating
        # `class ApplicationRecord < ActiveRecord::Base`) and then constantize
        # a user-configured Doorkeeper model that inherits from
        # `ApplicationRecord` while `ApplicationRecord` itself is still
        # mid-definition — raising `NameError: uninitialized constant
        # ApplicationRecord` (issue #1828).
        ::ActiveRecord::Base
      end

      def self.initialize_configured_associations
        # NOTE: on_load block is instance_exec'd on ActiveRecord::Base,
        #       so use fully qualified references (e.g. Doorkeeper.config).
        ActiveSupport.on_load(:active_record) do
          if Doorkeeper.config.enable_application_owner?
            Doorkeeper.config.application_model.include ::Doorkeeper::Models::Ownership
          end

          Doorkeeper.config.access_grant_model.include ::Doorkeeper::Models::PolymorphicResourceOwner::ForAccessGrant
          Doorkeeper.config.access_token_model.include ::Doorkeeper::Models::PolymorphicResourceOwner::ForAccessToken
        end
      end
    end
  end
end
