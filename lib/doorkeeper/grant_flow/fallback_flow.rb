# frozen_string_literal: true

module Doorkeeper
  module GrantFlow
    class FallbackFlow
      def handles_grant_type?
        false
      end

      def handles_response_type?
        false
      end

      def matches_grant_type?(_value)
        false
      end

      def matches_response_type?(_value)
        false
      end
    end
  end
end
