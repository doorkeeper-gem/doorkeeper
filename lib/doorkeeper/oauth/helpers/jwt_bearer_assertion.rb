# frozen_string_literal: true

require "jwt"

module Doorkeeper
  module OAuth
    module Helpers
      # Decodes and verifies an ID-JAG assertion (the `jwt-bearer` grant's
      # `assertion` parameter), per the Identity Assertion Authorization
      # Grant draft (draft-ietf-oauth-identity-assertion-authz-grant).
      #
      # The header is parsed *unverified* only to dispatch on `typ`/`kid`
      # (never to make a trust decision) before any cryptographic work; every
      # claim is only trusted once returned from a successful, signature
      # verified `#verify` call.
      module JwtBearerAssertion
        # The `typ` header value mandated by ID-JAG Section 3.1. Any other
        # value, including the generic `JWT`, is a type-confusion attempt.
        REQUIRED_TYP = "oauth-id-jag+jwt"

        REQUIRED_CLAIMS = %w[iss sub aud client_id jti exp iat].freeze

        # Result of a #verify call.
        #
        # @!attribute claims
        #   @return [Hash, nil] the verified claims, present only if +success?+
        Result = Struct.new(:claims) do
          def success?
            !claims.nil?
          end
        end

        FAILURE = Result.new(nil).freeze

        module_function

        # @param assertion [String] the compact JWT from the `assertion` request parameter
        # @param client [Doorkeeper::OAuth::Client] the authenticated client
        # @param config [Doorkeeper::Config] (default: +Doorkeeper.config+)
        # @return [Result]
        def verify(assertion, client:, config: Doorkeeper.config)
          return FAILURE unless assertion.is_a?(String) && assertion.present?

          candidates = resolve_key_candidates(assertion, config)
          return FAILURE if candidates.blank?

          claims = decode_with_candidates(assertion, candidates, client, config)
          return FAILURE unless claims

          Result.new(claims)
        end

        # Unverified header/payload dispatch: resolves which key(s) to
        # attempt verification against, without trusting any claim yet.
        def resolve_key_candidates(assertion, config)
          unverified_payload, unverified_header = peek(assertion)
          return [] unless unverified_payload && unverified_header
          return [] unless unverified_header["typ"] == REQUIRED_TYP

          issuer = unverified_payload["iss"]
          return [] unless issuer.is_a?(String) && issuer.present?
          return [] unless config.jwt_bearer_trusted_issuer.call(issuer)

          key_candidates(config.jwt_bearer_issuer_key.call(issuer, unverified_header["kid"]))
        end
        private_class_method :resolve_key_candidates

        # Parses the header/payload without verifying the signature or
        # trusting any claim. Used only to resolve which key to verify
        # against (RFC 7515 `kid`) and which issuer to look it up for.
        def peek(assertion)
          JWT.decode(assertion, nil, false)
        rescue JWT::DecodeError
          [nil, nil]
        end
        private_class_method :peek

        # Normalizes whatever `jwt_bearer_issuer_key` returned into a list of
        # objects `JWT::JWK.import` can build a key from: a PEM string is
        # converted via `OpenSSL::PKey.read`, a JWK `Hash`/`OpenSSL::PKey`/
        # `JWT::JWK::KeyBase` is passed through as-is.
        #
        # Deliberately does NOT use `Array(raw_key)` — Ruby's `Kernel#Array`
        # destructures a single `Hash` (a bare JWK) into `[[key, value], ...]`
        # pairs rather than wrapping it, which would silently drop the key.
        def key_candidates(raw_key)
          return [] if raw_key.blank?

          keys = raw_key.is_a?(Array) ? raw_key : [raw_key]

          keys.compact.filter_map do |key|
            key.is_a?(String) ? OpenSSL::PKey.read(key) : key
          rescue OpenSSL::PKey::PKeyError
            nil
          end
        end
        private_class_method :key_candidates

        # Tries each candidate key until one verifies the signature *and*
        # every claim. Every failure — bad signature, disallowed algorithm,
        # audience mismatch, expired/future timestamps, replay, missing
        # claims, `client_id` mismatch — is folded into the same `nil`
        # return so the caller cannot distinguish which check failed.
        def decode_with_candidates(assertion, candidates, client, config)
          allowed_algorithms = Array(config.jwt_bearer_allowed_algorithms)
          skew = config.jwt_bearer_clock_skew.to_i

          candidates.each do |key|
            jwk = begin
              JWT::JWK.import(key)
            rescue JWT::JWKError
              next
            end

            claims, = JWT.decode(
              assertion,
              jwk.verify_key,
              true,
              algorithms: allowed_algorithms,
              verify_aud: true,
              aud: config.jwt_bearer_audience,
              verify_expiration: true,
              exp_leeway: skew,
              verify_not_before: true,
              nbf_leeway: skew,
              required_claims: REQUIRED_CLAIMS,
              verify_jti: replay_validator(config),
            )

            next unless valid_iat?(claims, skew)
            next unless claims["client_id"] == client.uid

            return claims
          rescue JWT::DecodeError
            next
          end

          nil
        end
        private_class_method :decode_with_candidates

        # The `jwt` gem's own `verify_iat` has no leeway option, so the
        # future-dated-iat check (with our configurable clock skew) is done
        # manually here instead of via a decode option.
        def valid_iat?(claims, skew)
          claims["iat"].to_i <= Time.now.to_i + skew
        end
        private_class_method :valid_iat?

        # Builds the `verify_jti:` decode option: a `#call(jti, payload)`
        # validator the `jwt` gem invokes as part of claim verification.
        # Replay protection is opt-in — with no configured store, every jti
        # is accepted (a startup warning is logged elsewhere for this case).
        def replay_validator(config)
          lambda do |jti, payload|
            return false if jti.blank?

            store = config.jwt_bearer_replay_store
            next true unless store

            store.consume(jti, payload["iss"], payload["exp"])
          end
        end
        private_class_method :replay_validator
      end
    end
  end
end
