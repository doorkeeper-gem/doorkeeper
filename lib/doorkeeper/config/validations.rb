# frozen_string_literal: true

module Doorkeeper
  class Config
    # Doorkeeper configuration validator.
    #
    module Validations
      # The two token endpoint authentication methods RFC 8414 Section 2 names
      # as needing token_endpoint_auth_signing_alg_values_supported alongside
      # them. Matched on the IANA name a strategy declares, since that is what
      # the metadata document publishes.
      ASSERTION_AUTH_METHOD_NAMES = %w[private_key_jwt client_secret_jwt].freeze

      # Validates configuration options to be set properly.
      #
      def validate!
        validate_client_authentication_conflict
        validate_client_authentication_registered
        validate_reuse_access_token_value
        validate_token_reuse_limit
        validate_secret_strategies
        validate_pkce_code_challenge_methods
        validate_custom_metadata
        validate_refresh_token_flow
        validate_issuer_format
        validate_issuer_metadata_discoverability
        validate_client_id_metadata_documents_identity
        validate_client_id_metadata_documents_ownership
        validate_assertion_method_signing_algs
      end

      private

      # A Client ID Metadata Document client authenticating with
      # private_key_jwt has its assertions audience-checked against this
      # server's own identity, which RFC 7523 Section 3 requires and which
      # cannot be derived from the request: a document client_id resolves to
      # the same client, and the same keys, at every server implementing the
      # draft, so an assertion whose audience came from the Host header would
      # be replayable across all of them. PrivateKeyJwt therefore refuses such
      # an assertion outright when the server identifies itself nowhere, and
      # that refusal reaches the client as a bare invalid_client — so the
      # reason has to reach the operator here instead.
      def validate_client_id_metadata_documents_identity
        return unless client_id_metadata_documents?
        return unless private_key_jwt_configured?
        return if issuer.present?
        return if rails_default_url_host.present?

        ::Rails.logger.warn(
          "[DOORKEEPER] use_client_id_metadata_documents is enabled together with the " \
          "private_key_jwt client authentication method, but this server identifies itself " \
          "nowhere: neither the issuer option nor Rails' default_url_options[:host] is set. " \
          "A document client's assertion is checked against this server's own identity " \
          "(RFC 7523 Section 3), which must not be taken from the request's Host header, so " \
          "those assertions are refused unless one of the two is configured. Both are read " \
          "when Doorkeeper is configured; if you set Rails' default_url_options in a later " \
          "initializer, this warning does not apply. Registered applications authenticate " \
          "as they did before this option.",
        )
      end

      # A Client ID Metadata Document client is registered by no one: it
      # exists because a URL serves a document. So the application row it is
      # materialized as has no owner, and where ownership is enforced that row
      # never saves — leaving every document client refused as invalid_client,
      # with nothing in the response to say why. The two options are
      # incompatible; say so once at boot rather than never.
      def validate_client_id_metadata_documents_ownership
        return unless client_id_metadata_documents?
        return unless confirm_application_owner?

        ::Rails.logger.warn(
          "[DOORKEEPER] use_client_id_metadata_documents is enabled together with " \
          "enable_application_owner confirmation: true, which are incompatible: a document " \
          "client is registered by no one, so the application row it is materialized as has " \
          "no owner and fails that validation. Every Client ID Metadata Document client will " \
          "be refused as invalid_client until one of the two options is turned off. " \
          "Pre-registered applications are unaffected.",
        )
      end

      # The raw configured names are looked up in the registry one by one
      # rather than through +client_authentication_methods+, so this validation
      # does not memoise that resolution while configuration is still being
      # assembled. What each entry is matched on is the strategy itself, not
      # the key it is registered under: a host application is free to register
      # the method under another key, and it is the strategy — the one that
      # performs the audience check the warning is about — that decides.
      # Legacy callable adapters are wrapped as Method objects by the
      # deprecated +client_credentials+ option, which this reader never
      # returns, and an unregistered entry resolves to nil, so neither can
      # match.
      # RFC 8414 Section 2 has token_endpoint_auth_signing_alg_values_supported
      # published whenever an assertion-based method is advertised, and defines
      # no default for it, so the metadata document is non-compliant when a
      # strategy declares one of those names without declaring what it accepts.
      # Doorkeeper's own private_key_jwt declares its algorithms; this is about
      # a host application's strategy, whose metadata entry it would otherwise
      # be silently missing.
      #
      # Warned about rather than raised on, and the method is still advertised:
      # it authenticates clients perfectly well, and withholding it from
      # discovery would hide a working method to fix a missing one.
      #
      # Matched on the name the metadata endpoint will publish, which is the
      # declared one or, for a strategy declaring none, its registration key
      # (MetadataResponse reads `auth_method_name || name`). A host that
      # registers its strategy as :client_secret_jwt and declares nothing
      # advertises that method just the same, and would otherwise be the one
      # configuration this warning missed.
      def validate_assertion_method_signing_algs
        undeclared = client_authentication.filter_map do |name|
          method = Doorkeeper::ClientAuthentication.get(name)
          next unless method
          next unless ASSERTION_AUTH_METHOD_NAMES.include?((method.auth_method_name || method.name).to_s)

          name if method.auth_signing_alg_values.nil?
        end
        return if undeclared.empty?

        ::Rails.logger.warn(
          "[DOORKEEPER] #{undeclared.map(&:to_s).join(", ")} declares an assertion-based " \
          "token endpoint authentication method but no auth_signing_alg_values. RFC 8414 " \
          "Section 2 requires token_endpoint_auth_signing_alg_values_supported whenever " \
          "private_key_jwt or client_secret_jwt is advertised, and defines no default, so " \
          "the authorization server metadata is published without it. Declare the JWS \"alg\" " \
          "values the strategy accepts.",
        )
      end

      def private_key_jwt_configured?
        client_authentication.any? do |name|
          method = Doorkeeper::ClientAuthentication.get(name)

          method&.strategy == Doorkeeper::OAuth::ClientAuthentication::PrivateKeyJwt
        end
      end

      # Read defensively: Doorkeeper is configured from an initializer, and a
      # host application may not have routes (or an application object) yet.
      def rails_default_url_host
        ::Rails.application&.routes&.default_url_options&.[](:host)
      rescue StandardError
        nil
      end

      # Warn once, at configuration time, when both the deprecated
      # +client_credentials+ and the new +client_authentication+ options are
      # set. +client_authentication+ takes precedence; the warning lives here
      # (rather than in the memoised resolver) so it is not swallowed and
      # surfaces during boot instead of on the first request.
      def validate_client_authentication_conflict
        return unless instance_variable_defined?(:@client_credentials_methods) &&
                      instance_variable_defined?(:@client_authentication)

        ::Rails.logger.warn(
          "[DOORKEEPER] Both client_credentials and client_authentication are set, " \
          "using client_authentication",
        )
      end

      # Warn about configured client authentication methods that are not
      # registered (e.g. a typo, or an extension that failed to load). Such
      # names are silently ignored when resolving the methods, which could
      # otherwise leave the application with no usable authentication methods.
      def validate_client_authentication_registered
        # The deprecated client_credentials path already validates its own input.
        return if instance_variable_defined?(:@client_credentials_methods) &&
                  !instance_variable_defined?(:@client_authentication)

        configured = client_authentication
        unknown = configured.reject { |name| Doorkeeper::ClientAuthentication.get(name) }

        unless unknown.empty?
          ::Rails.logger.warn(
            "[DOORKEEPER] Unknown client authentication method(s) configured and will be ignored: " \
            "#{unknown.map(&:inspect).join(", ")}. " \
            "Ensure each method is registered (e.g. by the extension that provides it).",
          )
        end

        # A configuration that resolves to zero usable methods fails every
        # client authentication attempt (all requests fall back to no
        # credentials), so make that loud rather than silent.
        return unless (configured - unknown).empty?

        ::Rails.logger.error(
          "[DOORKEEPER] No usable client authentication methods are configured " \
          "(client_authentication resolved to an empty set). All client authentication " \
          "will fail. Configure at least one registered method, e.g. " \
          "client_authentication #{Doorkeeper::ClientAuthentication::DEFAULT_METHODS.inspect}.",
        )
      end

      # Determine whether +reuse_access_token+ and a non-restorable
      # +token_secret_strategy+ have both been activated.
      #
      # In that case, disable reuse_access_token value and warn the user.
      def validate_reuse_access_token_value
        strategy = token_secret_strategy
        return if !reuse_access_token || strategy.allows_restoring_secrets?

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured both reuse_access_token " \
          "AND '#{strategy}' strategy which cannot restore tokens. " \
          "This combination is unsupported. reuse_access_token will be disabled",
        )
        @reuse_access_token = false
      end

      # Validate that the provided strategies are valid for
      # tokens and applications
      def validate_secret_strategies
        token_secret_strategy.validate_for(:token)
        application_secret_strategy.validate_for(:application)
      end

      def validate_token_reuse_limit
        return if !reuse_access_token ||
                  (token_reuse_limit > 0 && token_reuse_limit <= 100)

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for token_reuse_limit option. " \
          "It will be set to default 100",
        )
        @token_reuse_limit = 100
      end

      def validate_pkce_code_challenge_methods
        methods = pkce_code_challenge_methods.map(&:to_s)
        if methods.all? { |method| method.match?(/\A(?:plain|S256)\z/) }
          # Persist the normalized (string) values only when the option was
          # explicitly configured — the default is already normalized, and an
          # unconfigured option should stay undefined rather than have
          # validation flip its instance_variable_defined? signal.
          @pkce_code_challenge_methods = methods if instance_variable_defined?(:@pkce_code_challenge_methods)
          return
        end

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for pkce_code_challenge_methods option. " \
          "It will be set to default ['plain', 'S256']",
        )

        @pkce_code_challenge_methods = ["plain", "S256"]
      end

      def validate_custom_metadata
        return if custom_metadata.is_a? Hash

        ::Rails.logger.warn(
          "[DOORKEEPER] You have configured an invalid value for custom_metadata option. " \
          "It must be a Hash, and will be overridden with an empty hash.",
        )

        @custom_metadata = {}
      end

      # Warn when the refresh_token grant flow is enabled but refresh tokens
      # are never issued: refresh token requests would always fail because
      # there are no tokens to refresh. The flow is enabled automatically
      # when +use_refresh_token+ is configured, so it doesn't need to be
      # listed in +grant_flows+ explicitly.
      #
      # +calculate_grant_flows+ is used (rather than the raw +grant_flows+) so
      # that the flow is also detected when enabled through a registered
      # grant-flow alias. When +use_refresh_token+ is not configured the
      # refresh_token flow is not appended implicitly, so its presence there
      # means it was requested explicitly (directly or via an alias).
      def validate_refresh_token_flow
        return if refresh_token_enabled?
        return unless calculate_grant_flows.map(&:to_s).include?("refresh_token")

        ::Rails.logger.warn(
          "[DOORKEEPER] You have enabled the refresh_token grant flow without " \
          "configuring use_refresh_token, so refresh tokens will not be issued. " \
          "Configure use_refresh_token to issue refresh tokens (the refresh_token " \
          "grant flow is then enabled automatically).",
        )
      end

      # Warn when a configured issuer is not RFC-compliant. RFC 8414 (the
      # metadata issuer) and RFC 9207 (the authorization response iss parameter)
      # both require an https URL with a host and no query or fragment component.
      # The value is still used as-is - this is a warning, not a hard failure, so
      # local setups using e.g. http://localhost keep working - but a
      # non-compliant issuer produces responses that strict clients may reject.
      def validate_issuer_format
        return if issuer.blank?

        uri =
          begin
            URI.parse(issuer.to_s)
          rescue URI::InvalidURIError
            nil
          end

        return if uri.is_a?(URI::HTTPS) && uri.host.present? &&
                  uri.query.nil? && uri.fragment.nil?

        ::Rails.logger.warn(
          "[DOORKEEPER] issuer #{redacted_issuer.inspect} is not RFC-compliant: " \
          "RFC 8414 and RFC 9207 require an https URL with a host and no query " \
          "or fragment component. It is still advertised in the metadata and " \
          "emitted as the iss parameter as-is, but strict clients may reject it.",
        )
      end

      # Warn when a path-bearing issuer cannot be discovered. RFC 8414 clients
      # build the metadata URL by inserting the well-known path into the issuer,
      # so an issuer of https://host/tenant is looked up at
      # https://host/.well-known/oauth-authorization-server/tenant. Doorkeeper
      # only serves the document at the root well-known path, so such a value is
      # not discoverable (and its advertised issuer would not match the lookup).
      # This is a separate concern from validate_issuer_format: a path component
      # is valid per RFC 8414, just unsupported by Doorkeeper's fixed route.
      def validate_issuer_metadata_discoverability
        return if issuer.blank?

        uri =
          begin
            URI.parse(issuer.to_s)
          rescue URI::InvalidURIError
            nil
          end

        return if uri&.host.blank?
        return if uri.path.blank? || uri.path == "/"

        ::Rails.logger.warn(
          "[DOORKEEPER] issuer #{redacted_issuer.inspect} has a path component, but " \
          "Doorkeeper serves its RFC 8414 metadata only at the root " \
          "/.well-known/oauth-authorization-server. RFC 8414 clients derive the " \
          "metadata URL from the issuer path (…/.well-known/" \
          "oauth-authorization-server#{uri.path}), so they will not discover the " \
          "document. Use a host-only issuer, or route the derived well-known path " \
          "to Doorkeeper.",
        )
      end

      # Redact any userinfo (e.g. a misconfigured user:pass@host) before the
      # issuer is written to the log, so credentials are not leaked there.
      def redacted_issuer
        issuer.to_s.sub(%r{//[^/@]*@}, "//***@")
      end
    end
  end
end
