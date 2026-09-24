# frozen_string_literal: true

require "json"
require "uri"

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class PrivateKeyJwt
        # Resolves the JWK Set a client's assertion must verify against.
        #
        # For a Client ID Metadata Document client the keys come from its
        # (memoized) document — inline +jwks+ or a fetched +jwks_uri+. For a
        # registered application they come from +jwks+ / +jwks_uri+ attributes
        # when the application model provides them (Doorkeeper defines no such
        # columns itself).
        #
        # Keys that are not public are dropped: a symmetric ("oct") key in a
        # JWK Set is a shared secret, which this method must never verify
        # against, and a key carrying private parameters is one whose owner
        # has published its own credential.
        #
        # The jwt gem is always referenced as ::JWT: doorkeeper-jwt defines
        # Doorkeeper::JWT, which would otherwise shadow the gem everywhere
        # inside this module.
        module KeyResolver
          # The JWK members that carry private key material: "d" for EC
          # (RFC 7518 Section 6.2.2), RSA (Section 6.3.2) and OKP (RFC 8037
          # Section 2) keys, the remaining RSA CRT parameters
          # (Section 6.3.2), and "k", the value of a symmetric key
          # (Section 6.4.1).
          NON_PUBLIC_MEMBERS = %w[d p q dp dq qi oth k].freeze

          # An "oct" key is symmetric whether or not it carries its "k".
          SYMMETRIC_KEY_TYPE = "oct"

          # The JWK Set of a registered application: its +jwks+ / +jwks_uri+
          # attributes, when the application model provides them.
          def self.jwk_set_for(application)
            key_set(application_jwks(application) || fetch_jwks(application_jwks_uri(application)))
          end

          # The JWK Set of a Client ID Metadata Document client: the +jwks+
          # its (memoized) document carries inline, or the set fetched from
          # the +jwks_uri+ it names. Which of the two kinds a client_id is
          # was decided by the caller (see PrivateKeyJwt.authenticate), from
          # the application table; nothing here judges it by its shape, so a
          # registered application's URL is never fetched by mistake.
          def self.document_jwk_set_for(client_id)
            document = Doorkeeper::ClientIdMetadata.document_for(client_id)
            return unless document

            # Section 8.2: client authentication must be "of the registered
            # type". A document that selected another method (such as
            # "none") may still publish a JWK Set, but those keys register
            # no authentication method and must not verify an assertion.
            return unless document.token_endpoint_auth_method == PrivateKeyJwt::AUTH_METHOD_NAME

            key_set(document.jwks || fetch_jwks(document.jwks_uri, cache: document_jwks_cache))
          end

          # Everything here is attacker-supplied for a metadata document
          # client, so each level is type-checked before it is indexed into:
          # a JWK Set that is not an object of objects must fail
          # authentication, never raise out of the token endpoint.
          def self.key_set(raw)
            return unless raw.is_a?(Hash)

            keys = raw["keys"] || raw[:keys]
            return unless keys.is_a?(Array)

            usable = keys.grep(Hash).select { |key| public_key?(key) && verification_key?(key) }
            return if usable.empty?

            build_key_set(usable)
          end
          private_class_method :key_set

          # Verifying an assertion needs no private parameter, so a key
          # carrying one verifies nothing here. For a Client ID Metadata
          # Document the draft says as much (Section 4.1: "only public keys
          # ... are permitted"); an inline jwks publishing such a key is
          # rejected with the document, while a set fetched from a jwks_uri
          # — which is not part of the document — is filtered here instead.
          # A registered application's key set is held to the same rule: it
          # is used for verification only, so nothing correctly published
          # there carries private material either.
          #
          # Judged on the value, the way a document's optional members are: a
          # key serialized with nulls for the private parameters it does not
          # have publishes none of them, and the jwt gem reads it as the
          # public key it is.
          def self.public_key?(key)
            return false if member(key, "kty").to_s == SYMMETRIC_KEY_TYPE

            NON_PUBLIC_MEMBERS.none? { |name| !member(key, name).nil? }
          end

          # Whether the publisher allows this key to verify a signature. RFC
          # 7517 Sections 4.2 and 4.3 let them say otherwise with "use" or
          # "key_ops", and the jwt gem honours neither — its key finder matches
          # on "kid" alone — so a client that publishes a JWE encryption key
          # beside its signing key would have that restriction ignored here.
          #
          # Deliberately not folded into public_key?, which Document uses to
          # refuse a whole document: publishing an encryption key in a metadata
          # document is legitimate, verifying an assertion with it is not.
          def self.verification_key?(key)
            use = member(key, "use")
            return false if use.is_a?(String) && use != "sig"

            ops = member(key, "key_ops")
            return true unless ops.is_a?(Array)

            ops.include?("verify")
          end
          private_class_method :verification_key?

          # A JWK reaches here parsed from JSON (string members) or straight
          # from an application model, where a Ruby Hash may well be keyed by
          # symbols.
          def self.member(key, name)
            key[name] || key[name.to_sym]
          end
          private_class_method :member

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

          # The jwks_uri is fetched with the same hardened HTTP client used
          # for metadata documents: https only, no redirects, 200 OK only,
          # and RFC 6890 special-use addresses refused.
          #
          # The result is memoized, since otherwise every single authenticated
          # request would fetch it again. By default the memo expires on the
          # same 60-second TTL as a metadata document, so a rotated key is
          # picked up within the same window as any other metadata change
          # (Section 8.4.1); a configured private_key_jwt_jwks_cache brings
          # its own TTL for registered applications, while document keys stay
          # on the built-in cache (see document_jwks_cache). Only JSON objects
          # are stored, so a malformed response is not cached.
          def self.fetch_jwks(jwks_uri, cache: jwks_cache)
            return if jwks_uri.blank?

            url = jwks_uri.to_s
            return unless URI.parse(url).is_a?(URI::HTTPS)

            cache.fetch(url) do
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

          # Keys named by a metadata document are cached apart from those of
          # registered applications. The built-in cache holds a fixed number
          # of entries and evicts the oldest, and which URLs go into this one
          # is chosen by whoever hosts a client_id — an unauthenticated
          # request is enough, since the keys have to be fetched before the
          # assertion they verify can be checked. Sharing one cache would let
          # that traffic evict the entries registered clients depend on, so
          # a configured private_key_jwt_jwks_cache is deliberately not
          # consulted here: it serves registered clients, and routing
          # unauthenticated document traffic into it would reopen the
          # eviction — or the unbounded growth — this separation prevents.
          def self.document_jwks_cache
            @document_jwks_cache ||= Doorkeeper::DocumentCache.new
          end
        end
      end
    end
  end
end
