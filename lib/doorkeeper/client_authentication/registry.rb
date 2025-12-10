# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    module Registry
      mattr_accessor :methods
      self.methods = {}

      # Allows to register custom OAuth client authentication method so that
      # Doorkeeper could recognize and process it.
      #
      def register(name, method)
        name_key = name.to_sym

        if methods.key?(name_key)
          ::Kernel.warn <<~WARNING
            [DOORKEEPER] '#{name_key}' client authentication strategy is already registered and will be overridden
            in #{caller(1..1).first}
          WARNING
        end

        methods[name_key] = Doorkeeper::ClientAuthentication::Method.new(name, method)
      end

      # [NOTE]: make it to use #fetch after removing fallbacks
      def get(name)
        methods[name.to_sym]
      end
    end
  end
end
