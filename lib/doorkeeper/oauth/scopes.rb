# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Scopes
      include OAuth::ListLike

      alias has_scopes? contains_all?
      alias scopes? contains_all?

      private

      def to_array(other)
        case other
        when Scopes
          other.all
        else
          other.to_a
        end
      end
    end
  end
end
