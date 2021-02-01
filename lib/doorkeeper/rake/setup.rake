# frozen_string_literal: true

namespace :doorkeeper do
  task setup: :environment do
    # Dirty hack to manually initialize AR because of lazy auto-loading,
    # in other case we'll see NameError: uninitialized constant Doorkeeper::AccessToken
    if Doorkeeper.config.orm == :active_record && defined?(::ActiveRecord::Base)
      Object.const_get("::ActiveRecord::Base")
    end
  end
end
