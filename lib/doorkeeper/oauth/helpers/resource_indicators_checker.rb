# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module Helpers
      # ResourceIndicatorsChecker validates that a provided set of indicators is valid
      # for a given grant. A grant should contain the same or more grants for any provided set.
      module ResourceIndicatorsChecker
        def self.valid?(grant, requested_indicators)
          return true unless Doorkeeper.config.using_resource_indicators?

          grant.resource_indicators.contains_all?(requested_indicators)
        end
      end
    end
  end
end
