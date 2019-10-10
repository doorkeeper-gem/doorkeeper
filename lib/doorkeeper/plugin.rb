# frozen_string_literal: true

module Doorkeeper
  # Doorkeeper "synthetic sugar" for plugin management.
  #
  module Plugin
    def self.run_for(namespace, **context)
      Doorkeeper::Plugin::Registry.run_for(namespace, context)
    end

    def self.register(*args)
      Doorkeeper::Plugin::Registry.register(*args)
    end
  end
end
