# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    module Registry
      mattr_accessor :mechanisms
      self.mechanisms = {}

      # Allows to register custom OAuth client authentication mechanism so that
      # Doorkeeper could recognize and process it.
      #
      def register(name_or_mechanism, **options)
        unless name_or_mechanism.is_a?(Doorkeeper::ClientAuthentication::Mechanism)
          name_or_mechanism = Doorkeeper::ClientAuthentication::Mechanism.new(name_or_mechanism, **options)
        end

        name_key = name_or_mechanism.name.to_sym

        if mechanisms.key?(name_key)
          ::Kernel.warn <<~WARNING
            [DOORKEEPER] '#{name_key}' client authentication strategy is already registered and will be overridden
            in #{caller(1..1).first}
          WARNING
        end

        mechanisms[name_key] = name_or_mechanism
      end

      # [NOTE]: make it to use #fetch after removing fallbacks
      def get(name)
        mechanisms[name.to_sym]
      end
    end
  end
end
