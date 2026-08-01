# frozen_string_literal: true

require "json"
require "uri"

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class PrivateKeyJwt
        # Resolves the JWK Set a client's assertion must verify against:
        # the +jwks+ / +jwks_uri+ attributes of its application, when the
        # application model provides them (Doorkeeper defines no such
        # columns itself).
        #
        # Symmetric ("oct") keys are dropped: a symmetric key in a JWK Set is
        # a shared secret, which this method must never verify against.
        #
        # The jwt gem is always referenced as ::JWT: doorkeeper-jwt defines
        # Doorkeeper::JWT, which would otherwise shadow the gem everywhere
        # inside this module.
        module KeyResolver
          # A published JWK Set is remote, client-controlled input, so each
          # level is type-checked before it is indexed into: a JWK Set that
          # is not an object of objects must fail authentication, never
          # raise out of the token endpoint.
          def self.jwk_set_for(application)
            raw = raw_jwks(application)
            return unless raw.is_a?(Hash)

            keys = raw["keys"] || raw[:keys]
            return unless keys.is_a?(Array)

            asymmetric = keys.grep(Hash).reject { |key| (key["kty"] || key[:kty]).to_s == "oct" }
            return if asymmetric.empty?

            build_key_set(asymmetric)
          end

          def self.raw_jwks(application)
            application_jwks(application) || fetch_jwks(application_jwks_uri(application))
          end
          private_class_method :raw_jwks

          # RFC 7517 gives the members the jwt gem parses a string value, and
          # the gem trusts that: a member carrying a JSON number, object or
          # array is indexed into as if it were a string, which raises
          # NoMethodError — neither a JWT::DecodeError nor an OpenSSL error,
          # so it would escape the rescue above and surface as a 500. The keys
          # are not filtered on their member types to head that off, because a
          # JWK Set may legitimately carry members that are not strings ("ext"
          # is a boolean in anything WebCrypto exports); a key that cannot be
          # built simply verifies nothing, as it already does for one whose
          # base64url is malformed.
          #
          # A member whose bytes are not valid UTF-8 raises ArgumentError out
          # of the base64url decoder, eagerly for a key without a kid (its
          # thumbprint is computed on the way in). The fetcher refuses such a
          # body; a registered application's jwks is the host's to fill.
          #
          # Built one key at a time, because JWT::JWK::Set builds them all in
          # its constructor and the first failure would take the whole set
          # with it: the gem knows RSA, EC and oct only, so one Ed25519 key
          # published beside a usable RSA one — or one entry with no "kty" —
          # would otherwise stop the client authenticating at all. RFC 7517
          # Section 5 asks for the opposite: a JWK Set member an
          # implementation does not understand is ignored, not fatal.
          def self.build_key_set(keys)
            usable = keys.filter_map { |key| build_key(key) }
            return if usable.empty?

            # No rescue here: every way a key can fail to parse is caught in
            # build_key, one key at a time, and what is handed over is a list
            # of JWK objects the Set only has to hold.
            ::JWT::JWK::Set.new(usable)
          end
          private_class_method :build_key_set

          # A hostile or simply unsupported key can fail to parse in more ways
          # than JWT::JWKError: a member that is not valid base64url raises
          # JWT::Base64DecodeError (a sibling of JWT::JWKError under
          # JWT::DecodeError, not a subclass), an EC point that is not on its
          # curve raises a bare OpenSSL error, and a member carrying a JSON
          # number, object or array is indexed into as a string. None of them
          # may escape into the token endpoint, and none of them may cost the
          # client the keys that are fine.
          def self.build_key(key)
            jwk = ::JWT::JWK.new(key)
            # Forces the parse the gem defers when a "kid" is present: left
            # lazy, a malformed member raises out of the key finder while it
            # walks the set looking for another key's kid, taking the whole
            # verification down with it. Failing here costs only its own key.
            jwk.verify_key
            jwk
          rescue ::JWT::DecodeError, OpenSSL::OpenSSLError, TypeError, NoMethodError, ArgumentError
            nil
          end
          private_class_method :build_key

          def self.application_jwks(application)
            return unless application.respond_to?(:jwks)

            jwks = application.jwks
            jwks.is_a?(String) ? JSON.parse(jwks) : jwks.presence
          rescue JSON::ParserError
            nil
          end
          private_class_method :application_jwks

          def self.application_jwks_uri(application)
            application.jwks_uri if application.respond_to?(:jwks_uri)
          end
          private_class_method :application_jwks_uri

          # The jwks_uri is fetched with a hardened HTTP client: https only,
          # no redirects, 200 OK only, and RFC 6890 special-use addresses
          # refused.
          #
          # The result is memoized, since otherwise every single authenticated
          # request would fetch it again; a rotated key is picked up once the
          # memo expires. Only JSON objects are stored, so a malformed
          # response is not cached.
          def self.fetch_jwks(jwks_uri)
            return if jwks_uri.blank?

            url = jwks_uri.to_s
            return unless URI.parse(url).is_a?(URI::HTTPS)

            jwks_cache.fetch(url) do
              parsed = JSON.parse(Doorkeeper::HttpFetcher.new.fetch(url))
              parsed if parsed.is_a?(Hash)
            end
          rescue Doorkeeper::HttpFetcher::FetchError, JSON::ParserError, URI::InvalidURIError
            nil
          end
          private_class_method :fetch_jwks

          # The built-in cache is process-local with a fixed TTL; the
          # private_key_jwt_jwks_cache config option replaces it with any
          # object answering fetch(url) { ... }.
          def self.jwks_cache
            Doorkeeper.config.private_key_jwt_jwks_cache || default_jwks_cache
          end

          def self.default_jwks_cache
            @default_jwks_cache ||= Doorkeeper::DocumentCache.new
          end
          private_class_method :default_jwks_cache
        end
      end
    end
  end
end
