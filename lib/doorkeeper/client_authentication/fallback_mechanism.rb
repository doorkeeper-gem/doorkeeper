# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class FallbackMechanism
      def authenticate(request)
        nil
      end
    end
  end
end
