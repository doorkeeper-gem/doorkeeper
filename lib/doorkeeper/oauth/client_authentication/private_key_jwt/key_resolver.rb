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

            JWT::JWK::Set.new({ "keys" => asymmetric })
          rescue JWT::DecodeError, OpenSSL::OpenSSLError
            # A hostile key can fail to parse in more ways than JWT::JWKError:
            # a member that is not valid base64url raises JWT::Base64DecodeError
            # (a sibling of JWT::JWKError under JWT::DecodeError, not a
            # subclass), and an EC point that is not on its curve raises a bare
            # OpenSSL error. None of them may escape into the token endpoint.
            nil
          end

          def self.raw_jwks(application, client_id)
            if Doorkeeper::ClientIdMetadata.url_client_id?(client_id)
              document = Doorkeeper::ClientIdMetadata.document_for(client_id)
              return unless document

              document.jwks || fetch_jwks(document.jwks_uri)
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
          # request would fetch it again. The memo shares the metadata document
          # TTL, so a rotated key is picked up within the same window as any
          # other metadata change (Section 6.3.1). Only JSON objects are
          # stored, so a malformed response is not cached.
          def self.fetch_jwks(jwks_uri)
            return if jwks_uri.blank?

            url = jwks_uri.to_s
            return unless URI.parse(url).is_a?(URI::HTTPS)

            jwks_cache.fetch(url) do
              parsed = JSON.parse(Doorkeeper::ClientIdMetadata::HttpFetcher.new.fetch(url))
              parsed if parsed.is_a?(Hash)
            end
          rescue Doorkeeper::ClientIdMetadata::HttpFetcher::FetchError, JSON::ParserError, URI::InvalidURIError
            nil
          end
          private_class_method :fetch_jwks

          def self.jwks_cache
            @jwks_cache ||= Doorkeeper::ClientIdMetadata::DocumentCache.new
          end
        end
      end
    end
  end
end
