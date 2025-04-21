# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class FallbackMethod
      def self.matches_request?(request)
        true
      end

      def self.authenticate(request)
        nil
      end
    end
  end
end
