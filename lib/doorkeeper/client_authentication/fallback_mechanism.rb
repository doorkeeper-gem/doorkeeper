# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    class FallbackMechanism
      def authenticate(request)
        Doorkeeper::ClientAuthentication::Credentials.new(nil, nil)
      end
    end
  end
end
