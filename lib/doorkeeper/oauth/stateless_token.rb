# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # In-memory representation of a verified JWT access token. Returned by
    # OAuth::Token.authenticate when stateless_jwt_tokens is enabled, so that
    # the existing doorkeeper_token / doorkeeper_authorize! helpers work
    # without any database read.
    #
    # Stateless tokens cannot be revoked or refreshed server-side: #revoked?
    # is always false and #revoke is a no-op. Rely on short token lifetimes
    # (access_token_expires_in) for early invalidation.
    class StatelessToken
      attr_reader :claims, :application, :raw_token

      def initialize(claims:, application: nil, raw_token: nil)
        @claims = claims
        @application = application
        @raw_token = raw_token
      end

      def token_type
        "Bearer"
      end

      # The raw token string. Used by introspection's
      # authorized_token_matches_introspected? security check.
      def token
        @raw_token
      end

      # Issuance path: the freshly-signed JWT returned to the client.
      def plaintext_token
        @raw_token
      end

      def plaintext_refresh_token
        nil
      end

      def resource_owner_id
        claims["resource_owner_id"] || claims["sub"]
      end

      def application_id
        application&.id
      end

      def scopes_string
        claims["scope"].to_s
      end

      def scopes
        OAuth::Scopes.from_string(scopes_string)
      end

      def includes_scope?(*required_scopes)
        required_scopes.blank? || required_scopes.any? { |scope| scopes.exists?(scope.to_s) }
      end

      def custom_attributes
        claims.slice(*Doorkeeper.config.custom_access_token_attributes.map(&:to_s))
      end

      # RFC 8707 resource indicator. Stored as a space-delimited string to
      # match the AccessToken column shape consumed by token_introspection.
      def resource
        aud = claims["aud"]
        return nil if aud.blank?

        aud.is_a?(Array) ? aud.join(" ") : aud.to_s
      end

      def created_at
        Time.at(claims["iat"].to_i).utc
      end

      def expires_in
        claims["expires_in"]
      end

      def expires_at
        return nil unless claims["exp"]

        Time.at(claims["exp"].to_i).utc
      end

      def expires_in_seconds
        return nil unless expires_at

        expires = expires_at - Time.now.utc
        sec = expires.seconds.round(0)
        sec > 0 ? sec : 0
      end

      def expired?
        return false unless expires_at

        Time.now.utc > expires_at
      end

      def revoked?
        false
      end

      def accessible?
        !expired? && !revoked?
      end

      def acceptable?(required_scopes)
        accessible? && includes_scope?(*required_scopes)
      end

      def revoke_previous_refresh_token!
        # no-op: stateless tokens carry no refresh-token chain to revoke.
      end

      def revoke
        # no-op: stateless tokens cannot be revoked server-side.
      end

      def revocable?
        false
      end

      def as_json(_options = {})
        {
          resource_owner_id: resource_owner_id,
          scope: scopes,
          expires_in: expires_in_seconds,
          application: { uid: application.try(:uid) },
          created_at: created_at.to_i,
        }.tap do |json|
          json[:resource_owner_type] = claims["resource_owner_type"] if Doorkeeper.configuration.polymorphic_resource_owner?
        end
      end
    end
  end
end
