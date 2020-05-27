# frozen_string_literal: true

module Doorkeeper
  module GrantFlow
    class FallbackFlow < Flow
      def handles_grant_type?
        false
      end

      def handles_response_type?
        false
      end
    end
  end
end
