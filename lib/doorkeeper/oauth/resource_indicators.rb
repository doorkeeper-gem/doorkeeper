# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # Represents a set of resource indicators, much like the matching Scope class.
    class ResourceIndicators
      include OAuth::ListLike

      alias has_resource_indicators? contains_all?
      alias resource_indicators? contains_all?

      def common_or_lesser(other)
        intersection(other)
      end

      private

      def to_array(other)
        case other
        when ResourceIndicators
          other.all
        else
          other.to_a
        end
      end
    end
  end
end
