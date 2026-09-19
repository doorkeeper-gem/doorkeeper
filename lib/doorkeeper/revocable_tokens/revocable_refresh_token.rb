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

      # RFC 7009 §2.1: revoking a refresh token SHOULD also invalidate the
      # access tokens based on the same authorization grant. The records of
      # one refresh chain share a refresh token family when the access token
      # model tracks it (see `AccessTokenMixin.refresh_token_family_supported?`);
      # otherwise only the record of the presented token is revoked.
      def revoke
        if token.respond_to?(:revoke_refresh_token_family)
          token.revoke_refresh_token_family
        else
          token.revoke
        end
      end
    end
  end
end
