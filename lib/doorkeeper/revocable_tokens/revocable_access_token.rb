# frozen_string_literal: true

module Doorkeeper
  module RevocableTokens
    class RevocableAccessToken
      attr_reader :token

      def initialize(token)
        @token = token
      end

      def revocable?
        token.accessible?
      end

      def revoke
        token.revoke
      end
    end
  end
end
