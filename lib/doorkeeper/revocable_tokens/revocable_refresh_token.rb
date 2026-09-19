# frozen_string_literal: true

module Doorkeeper
  module RevocableTokens
    class RevocableRefreshToken
      attr_reader :token

      def initialize(token)
        @token = token
      end

      # A refresh token revoked on its own (see
      # `AccessTokenMixin#refresh_token_revoked?`) is an invalid token for
      # the revocation endpoint, so presenting it must not reach the access
      # token that is still usable on the same record. Models that do not
      # implement the predicate revoke both tokens together.
      def revocable?
        if token.respond_to?(:refresh_token_revoked?)
          !token.refresh_token_revoked?
        else
          !token.revoked?
        end
      end

      # Revokes the whole record: RFC 7009 §2.1 asks that revoking a refresh
      # token also invalidates the access tokens based on the same grant.

      def revoke
        token.revoke
      end
    end
  end
end
