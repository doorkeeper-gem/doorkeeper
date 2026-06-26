# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Holds the registered client authentication methods and provides the DSL
    # to register and look them up by name.
    module Registry
      mattr_accessor :registered_methods
      self.registered_methods = {}

      # Allows to register a custom OAuth client authentication method so that
      # Doorkeeper could recognize and process it.
      #
      def register(name, method)
        name_key = name.to_sym

        if registered_methods.key?(name_key)
          ::Kernel.warn <<~WARNING
            [DOORKEEPER] '#{name_key}' client authentication strategy is already registered and will be overridden
            in #{caller(1..1).first}
          WARNING
        end

        registered_methods[name_key] = Doorkeeper::ClientAuthentication::Method.new(name, method)
      end

      # [NOTE]: switch to #fetch once the deprecated client_credentials
      # fallbacks are removed.
      def get(name)
        registered_methods[name.to_sym]
      end
    end
  end
end
