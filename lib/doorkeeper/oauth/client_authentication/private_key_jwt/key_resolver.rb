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
        # Symmetric ("oct") keys are dropped: a symmetric key in a JWK Set is
        # a shared secret, which this method must never verify against.
        #
        # The jwt gem is always referenced as ::JWT: doorkeeper-jwt defines
        # Doorkeeper::JWT, which would otherwise shadow the gem everywhere
        # inside this module.
        module KeyResolver
          # Everything here is attacker-supplied for a metadata document
          # client, so each level is type-checked before it is indexed into:
          # a JWK Set that is not an object of objects must fail
          # authentication, never raise out of the token endpoint.
          def self.jwk_set_for(application, client_id)
            raw = raw_jwks(application, client_id)
            return unless raw.is_a?(Hash)

            keys = raw["keys"] || raw[:keys]
            return unless keys.is_a?(Array)

            asymmetric = keys.grep(Hash).reject { |key| (key["kty"] || key[:kty]).to_s == "oct" }
            return if asymmetric.empty?

            build_key_set(asymmetric)
          rescue ::JWT::DecodeError, OpenSSL::OpenSSLError
            # A hostile key can fail to parse in more ways than JWT::JWKError:
            # a member that is not valid base64url raises JWT::Base64DecodeError
            # (a sibling of JWT::JWKError under JWT::DecodeError, not a
            # subclass), and an EC point that is not on its curve raises a bare
            # OpenSSL error. None of them may escape into the token endpoint.
            nil
          end

          # RFC 7517 gives the members the jwt gem parses a string value, and
          # the gem trusts that: a member carrying a JSON number, object or
          # array is indexed into as if it were a string, which raises
          # NoMethodError — neither a JWT::DecodeError nor an OpenSSL error,
          # so it would escape the rescue above and surface as a 500. The keys
          # are not filtered on their member types to head that off, because a
          # JWK Set may legitimately carry members that are not strings ("ext"
          # is a boolean in anything WebCrypto exports); a set that cannot be
          # built simply verifies nothing, as it already does for a key whose
          # base64url is malformed.
          def self.build_key_set(keys)
            ::JWT::JWK::Set.new({ "keys" => keys })
          rescue ::JWT::DecodeError, OpenSSL::OpenSSLError, TypeError, NoMethodError
            nil
          end
          private_class_method :build_key_set

          def self.raw_jwks(application, client_id)
            if Doorkeeper::ClientIdMetadata.url_client_id?(client_id)
              document = Doorkeeper::ClientIdMetadata.document_for(client_id)
              return unless document

              # Section 6.2: client authentication must be "of the registered
              # type". A document that selected another method (such as
              # "none") may still publish a JWK Set, but those keys register
              # no authentication method and must not verify an assertion.
              return unless document.token_endpoint_auth_method == PrivateKeyJwt::AUTH_METHOD_NAME

              document.jwks || fetch_jwks(document.jwks_uri, cache: document_jwks_cache)
            else
              application_jwks(application) || fetch_jwks(application_jwks_uri(application))
            end
          end
          private_class_method :raw_jwks

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
          # (Section 6.3.1); a configured private_key_jwt_jwks_cache brings
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
