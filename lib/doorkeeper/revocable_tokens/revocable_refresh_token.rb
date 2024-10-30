# frozen_string_literal: true

module Doorkeeper
  module RevocableTokens
    class RevocableRefreshToken
      attr_reader :token

      def initialize(token)
        @token = token
      end

      def revocable?
        !token.revoked?
      end

      def revoke
        token.revoke
      end
    end
  end
end
