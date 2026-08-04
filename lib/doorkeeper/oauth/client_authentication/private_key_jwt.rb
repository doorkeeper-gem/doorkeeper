# frozen_string_literal: true

require "uri"

require "doorkeeper/oauth/client_authentication/private_key_jwt/key_resolver"
require "doorkeeper/oauth/client_authentication/private_key_jwt/replay_guard"

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # "private_key_jwt" client authentication (RFC 7523 / OIDC Core §9):
      # the client authenticates with a JWT assertion signed by its private
      # key; the server verifies it against the client's published public
      # keys (a jwks attribute on the application model, or keys fetched
      # from its jwks_uri). No shared secret is involved.
      #
      # The "jwt" gem is required only when an assertion is actually
      # authenticated, so servers that don't enable this method don't need
      # the dependency. Its constants are always referenced as ::JWT:
      # doorkeeper-jwt defines Doorkeeper::JWT, which would otherwise shadow
      # the gem everywhere inside this class.
      class PrivateKeyJwt
        CLIENT_ASSERTION_TYPE = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"

        # Assertions are verified against the client's published public
        # keys; no shared secret is involved.
        def self.uses_shared_secret?
          false
        end

        # Asymmetric signature algorithms only: HMAC family (and "none") are
        # shared-secret/unauthenticated and must never verify an assertion.
        ALLOWED_ALGORITHMS = %w[RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512].freeze

        # iss/sub identify the client, aud prevents cross-server replay,
        # exp bounds the assertion lifetime and jti makes it single-use
        # (OIDC Core §9 requires all of these for private_key_jwt).
        REQUIRED_CLAIMS = %w[iss sub aud exp jti].freeze

        # Upper bound on how far in the future an assertion may expire. This
        # both rejects sloppily long-lived assertions and bounds the replay
        # guard's memory.
        MAX_LIFETIME = 3600

        def self.matches_request?(request)
          params = request.request_parameters.with_indifferent_access

          request.post? &&
            params[:client_assertion].present? &&
            params[:client_assertion_type] == CLIENT_ASSERTION_TYPE
        end

        def self.authenticate(request)
          require_jwt!

          params = request.request_parameters.with_indifferent_access
          assertion = params[:client_assertion].to_s

          client_id = unverified_client_id(assertion)
          return if client_id.blank?
          # RFC 7521 §4.2: a client_id parameter sent alongside the assertion
          # must agree with the assertion's issuer.
          return if params[:client_id].present? && params[:client_id] != client_id

          application = OAuth::Client.find(client_id)&.application
          return unless application

          jwk_set = KeyResolver.jwk_set_for(application)
          return unless jwk_set

          claims = verified_claims(assertion, client_id, jwk_set, request)
          return unless claims
          return unless replay_guard.first_use?(
            "#{client_id}:#{claims["jti"]}",
            expires_at: claims["exp"].to_i,
          )

          Doorkeeper::ClientAuthentication::VerifiedCredentials.new(client_id)
        end

        # The built-in guard is process-local; a multi-process deployment can
        # supply a shared store through the private_key_jwt_replay_guard
        # config option.
        def self.replay_guard
          Doorkeeper.config.private_key_jwt_replay_guard || ReplayGuard.instance
        end
        private_class_method :replay_guard

        # The issuer read without verifying the signature — only used to
        # locate the client (and thereby its keys); every claim is verified
        # against those keys before the assertion authenticates anyone.
        def self.unverified_client_id(assertion)
          claims, = ::JWT.decode(assertion, nil, false)
          # A JWT payload is any JSON value, not necessarily an object, and
          # nothing is verified at this point — so the decoded claims are
          # type-checked before being indexed into.
          return unless claims.is_a?(Hash)

          issuer = claims["iss"]

          issuer if issuer.is_a?(String) && issuer == claims["sub"]
        rescue ::JWT::DecodeError
          nil
        end
        private_class_method :unverified_client_id

        def self.verified_claims(assertion, client_id, jwk_set, request)
          claims, = ::JWT.decode(
            assertion,
            nil,
            true,
            algorithms: ALLOWED_ALGORITHMS,
            jwks: jwk_set,
            required_claims: REQUIRED_CLAIMS,
            iss: client_id,
            verify_iss: true,
            sub: client_id,
            verify_sub: true,
            aud: acceptable_audiences(request),
            verify_aud: true,
            # Passed explicitly so a host application that globally disabled
            # expiration checking for its own tokens (JWT.configuration.decode)
            # cannot silently turn off assertion expiry verification.
            verify_expiration: true,
          )

          # RFC 7519 §4.1.4: exp is a NumericDate — a number. The jwt gem's
          # own expiration check casts it with to_i, which would let a numeric
          # string through (and read a non-numeric one as 0), so the type is
          # pinned before the value is compared or handed to the replay guard.
          exp = claims["exp"]
          return unless exp.is_a?(Numeric) && exp.finite?
          return unless exp <= Time.now.to_i + MAX_LIFETIME
          return unless claims["jti"].is_a?(String) && claims["jti"].present?

          claims
        rescue ::JWT::DecodeError, OpenSSL::OpenSSLError
          # A published key is only parsed far enough to be usable when it is
          # actually needed to verify a signature, so a structurally valid but
          # mathematically nonsensical key (an EC point that is not on the
          # curve, say) surfaces here as a bare OpenSSL error rather than a
          # JWT one. Both mean the same thing: this assertion does not verify.
          nil
        end
        private_class_method :verified_claims

        # RFC 7523bis expects the issuer identifier as the audience; older
        # deployments use the token endpoint URL. Both are accepted.
        #
        # OIDC Core §9 says the audience SHOULD be the token endpoint URL, and
        # clients follow that for every endpoint they authenticate at — so the
        # token endpoint URL is accepted at the revocation and introspection
        # endpoints too, not just at the endpoint being called.
        #
        # The endpoint URLs are built from the server's own configured
        # identity, never from the request: aud is what keeps an assertion
        # minted for another authorization server from being replayed here, so
        # deriving it from the client-supplied Host header would defeat its
        # purpose on any deployment that does not filter hosts. Only a server
        # that identifies itself nowhere falls back to the request, which is
        # how MetadataResponse derives its issuer as well.
        def self.acceptable_audiences(request)
          options = server_url_options(request)

          [
            Doorkeeper.config.issuer.presence,
            "#{base_url(options)}#{request.path}",
            token_endpoint_url(options),
          ].compact.uniq
        end
        private_class_method :acceptable_audiences

        def self.server_url_options(request)
          configured_url_options ||
            { protocol: request.protocol, host: request.host, port: request.optional_port }
        end
        private_class_method :server_url_options

        # An explicitly configured canonical host wins; failing that, the
        # issuer, when it is an absolute URL (Doorkeeper allows any string).
        def self.configured_url_options
          default = ::Rails.application&.routes&.default_url_options || {}
          return url_options_from(default) if default[:host].present?

          issuer = URI.parse(Doorkeeper.config.issuer.to_s)
          return unless issuer.is_a?(URI::HTTP) && issuer.host.present?

          {
            protocol: "#{issuer.scheme}://",
            host: issuer.host,
            port: (issuer.port unless issuer.port == issuer.default_port),
          }
        rescue URI::InvalidURIError
          nil
        end
        private_class_method :configured_url_options

        def self.url_options_from(default)
          { protocol: default[:protocol] || "https://", host: default[:host], port: default[:port] }
        end
        private_class_method :url_options_from

        def self.base_url(options)
          protocol = options[:protocol].to_s
          protocol = "#{protocol}://" unless protocol.end_with?("://")
          host = options[:port].present? ? "#{options[:host]}:#{options[:port]}" : options[:host]

          "#{protocol}#{host}"
        end
        private_class_method :base_url

        # Built the way MetadataResponse advertises the token endpoint, so a
        # host application that renamed the tokens controller still gets the
        # URL its own metadata publishes.
        def self.token_endpoint_url(url_options)
          mapping = Doorkeeper::Rails::Routes.mapping[:tokens]
          return unless mapping

          ::Rails.application.routes.url_for(
            { controller: "/#{mapping[:controllers]}", action: "create" }.merge(url_options),
          )
        rescue StandardError
          # Routes may be skipped or unmounted; fall back to the other audiences.
          nil
        end
        private_class_method :token_endpoint_url

        # Enabling this method without the gem installed is a deployment
        # mistake, not a protocol error the client could correct — so the
        # explanation has to reach the operator rather than the client. A
        # Doorkeeper::Errors::DoorkeeperError would be translated into an OAuth
        # error response whose "error" value is its message (DoorkeeperError#type
        # returns the message), handing the client a sentence where a registered
        # error code belongs; LoadError keeps the diagnosis in the server's logs
        # and surfaces the request as the server error it is.
        def self.require_jwt!
          require "jwt"
        rescue LoadError
          raise LoadError,
                "private_key_jwt client authentication requires the 'jwt' gem (>= 2.7); " \
                "add it to your Gemfile to use this method"
        end
        private_class_method :require_jwt!
      end
    end
  end
end
