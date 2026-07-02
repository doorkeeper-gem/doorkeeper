# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    # Used when no registered client authentication method matches the
    # request. It matches everything and authenticates to nothing, mirroring
    # the previous behaviour where an unauthenticated request simply yielded
    # no credentials.
    class FallbackMethod
      def self.matches_request?(_request)
        true
      end

      def self.authenticate(_request)
        nil
      end
    end
  end
end
