# frozen_string_literal: true

module Doorkeeper
  module Models
    # Provides getters and setters for resource indicators. Since we can't rely on
    # database specifics like array types resource indicators are stored as a string
    # in the database - similar to scopes.
    module ResourceIndicators
      def resource_indicators
        OAuth::ResourceIndicators.from_string(resource_indicators_string)
      end

      def resource_indicators=(value)
        if value.is_a?(Array)
          super(Doorkeeper::OAuth::ResourceIndicators.from_array(value).to_s)
        else
          super(Doorkeeper::OAuth::ResourceIndicators.from_string(value.to_s).to_s)
        end
      end

      def resource_indicators_string
        self[:resource_indicators]
      end
    end
  end
end
