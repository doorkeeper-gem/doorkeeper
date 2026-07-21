# frozen_string_literal: true

module Doorkeeper
  # Reopened here (rather than in config.rb) to keep that already-large
  # class from growing further; see Metrics/ClassLength.
  class Config
    # Fail-closed default for a required `jwt_bearer_*` hook: warns once and returns +result+.
    def self.jwt_bearer_unconfigured(option_name, result = nil)
      ->(*) { ::Rails.logger.warn("[DOORKEEPER] #{option_name} is not configured") && result }
    end

    # JWT Bearer / ID-JAG grant (urn:ietf:params:oauth:grant-type:jwt-bearer):
    # acts as the Resource AS side of a Cross App Access exchange. Not
    # enabled unless `:jwt_bearer` is added to `grant_flows`.

    # This AS's issuer identifier (RFC 8414); assertions must present this as their `aud`.
    option :jwt_bearer_audience, default: nil

    # Clock-skew tolerance, in seconds, for `exp`/`nbf`/`iat`.
    option :jwt_bearer_clock_skew, default: 60

    # Signature algorithm allow-list; `none`/HMAC are never accepted.
    option :jwt_bearer_allowed_algorithms, default: %w[RS256 ES256 PS256]

    # ID-JAG §8.1: confidential-client-only unless relaxed (not for production).
    option :jwt_bearer_allow_public_clients, default: false

    # Required `(issuer) -> Boolean` hook: is `issuer` a trusted IdP? Fails closed by default.
    option :jwt_bearer_trusted_issuer, default: jwt_bearer_unconfigured(:jwt_bearer_trusted_issuer, false)

    # Required `(issuer, kid) -> key(s)` hook: PEM/`OpenSSL::PKey`/JWK `Hash`/`Array` of those.
    # Fails closed by default.
    option :jwt_bearer_issuer_key, default: jwt_bearer_unconfigured(:jwt_bearer_issuer_key)

    # Required `(issuer, subject, client) -> resource_owner` hook. Fails closed by default.
    option :jwt_bearer_resource_owner_from_assertion,
           default: jwt_bearer_unconfigured(:jwt_bearer_resource_owner_from_assertion)

    # Optional `(client, resource_owner, scopes, claims) -> Boolean` policy hook; permissive by default.
    option :jwt_bearer_authorize, default: ->(_client, _resource_owner, _scopes, _claims) { true }

    # Replay protection: responds to `#consume(jti, issuer, expires_at) -> Boolean`
    # (true only on first use of an `(issuer, jti)` pair). `nil` disables it
    # (logged once); supplying an app-backed store is strongly recommended.
    option :jwt_bearer_replay_store, default: nil
  end
end
