# frozen_string_literal: true

module Doorkeeper
  module RevocableTokens
    class RevocableRefreshToken
      attr_reader :token

      def initialize(token)
        @token = token
      end

      # A refresh token whose family is tracked stays revocable once its own
      # record is revoked: the records issued after it along the chain can
      # still be live, and revoking any refresh token of the chain is meant
      # to reach them.
      def revocable?
        !token.revoked? || refresh_token_family?
      end

      # RFC 7009 §2.1: revoking a refresh token SHOULD also invalidate the
      # access tokens based on the same authorization grant. The records of
      # one refresh chain share a refresh token family when the access token
      # model tracks it (see `AccessTokenMixin.refresh_token_family_supported?`);
      # otherwise only the record of the presented token is revoked.
      def revoke
        if refresh_token_family?
          token.revoke_refresh_token_family
        else
          token.revoke
        end
      end

      private

      # True when the record belongs to a refresh token family. Access token
      # models that do not track families at all (no column, or the Sequel
      # and MongoDB adapters, which ship their own mixins) never do.
      def refresh_token_family?
        token.respond_to?(:revoke_refresh_token_family) &&
          token.refresh_token_family_id.present?
      end
    end
  end
end
