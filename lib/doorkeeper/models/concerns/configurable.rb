# frozen_string_literal: true

module Doorkeeper
  module Models
    module Configurable
      extend ActiveSupport::Concern

      def doorkeeper_config
        self.class.doorkeeper_config
      end

      module ClassMethods
        # Returns the Doorkeeper configuration for this model
        def doorkeeper_config
          ::Doorkeeper.config
        end
      end
    end
  end
end
