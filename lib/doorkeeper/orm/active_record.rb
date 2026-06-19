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

      # Kept as a no-op so `Doorkeeper.run_orm_hooks` (and any plugin that
      # checks `respond_to?(:run_hooks)`) stays quiet. The model concerns
      # that used to be wired up here are now included from each Mixin's
      # `included` block, which runs at parent-class autoload time — well
      # after `Doorkeeper.configure` has applied user settings, and without
      # touching `ActiveSupport.on_load(:active_record)` (whose re-entrant
      # firing during `ApplicationRecord` autoload caused #1828).
      def self.run_hooks; end
    end
  end
end
