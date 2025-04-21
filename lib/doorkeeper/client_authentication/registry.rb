# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    module Registry
      mattr_accessor :methods
      self.methods = {}

      # Allows to register custom OAuth client authentication method so that
      # Doorkeeper could recognize and process it.
      #
      def register(name_or_method, **options)
        unless name_or_method.is_a?(Doorkeeper::ClientAuthentication::Method)
          name_or_method = Doorkeeper::ClientAuthentication::Method.new(name_or_method, **options)
        end

        name_key = name_or_method.name.to_sym

        if methods.key?(name_key)
          ::Kernel.warn <<~WARNING
            [DOORKEEPER] '#{name_key}' client authentication strategy is already registered and will be overridden
            in #{caller(1..1).first}
          WARNING
        end

        methods[name_key] = name_or_method
      end

      # [NOTE]: make it to use #fetch after removing fallbacks
      def get(name)
        methods[name.to_sym]
      end
    end
  end
end
