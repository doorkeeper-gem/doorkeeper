# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Helpers
      # ResourceIndicatorsChecker validates that a proded set of indicators is valid
      # for a given grant. A grant should contain the same or more grants for any provided set.
      module ResourceIndicatorsChecker
        def self.valid?(grant, requested_indicators)
          return true unless Doorkeeper.config.using_resource_indicators?
          return true if grant.resource_indicators.empty?

          requested_indicators.any? && grant.resource_indicators.contains_all?(requested_indicators)
        end
      end
    end
  end
end
