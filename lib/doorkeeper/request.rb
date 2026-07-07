# frozen_string_literal: true

module Doorkeeper
  module Request
    class << self
      # Detect the OAuth client authentication method (RFC 6749 §2.3) that the
      # given request uses. Returns the matching method's strategy (not the
      # registry's Method wrapper), or FallbackMethod when none matches
      # (which authenticates to no credentials).
      #
      # Raises Errors::MultipleClientAuthMethods when the request itself
      # uses more than one client authentication method, since RFC 6749 §2.3
      # forbids that (see +validate_client_authentication!+).
      def client_authentication_method(request)
        validate_client_authentication!(request)

        authentication_method = client_authentication_methods.detect do |method|
          method.matches_request?(request)
        end

        if authentication_method
          authentication_method.strategy
        else
          Doorkeeper::ClientAuthentication::FallbackMethod
        end
      end

      def authorization_strategy(response_type)
        grant_flow = authorization_flows.detect do |flow|
          flow.matches_response_type?(response_type)
        end

        if grant_flow
          grant_flow.response_type_strategy
        else
          # [NOTE]: this will be removed in a newer versions of Doorkeeper.
          # For retro-compatibility only
          build_fallback_strategy_class(response_type)
        end
      end

      def token_strategy(grant_type)
        raise Errors::MissingRequiredParameter, :grant_type if grant_type.blank?

        grant_flow = token_flows.detect do |flow|
          flow.matches_grant_type?(grant_type)
        end

        if grant_flow
          grant_flow.grant_type_strategy
        else
          # [NOTE]: this will be removed in a newer versions of Doorkeeper.
          # For retro-compatibility only
          raise Errors::InvalidTokenStrategy unless available.include?(grant_type.to_s)

          strategy_class = build_fallback_strategy_class(grant_type)
          raise Errors::InvalidTokenStrategy unless strategy_class

          strategy_class
        end
      end

      private

      # RFC 6749 §2.3 forbids clients to "use more than one authentication
      # method in each request", so the request payload is validated against
      # every *registered* method — regardless of which ones are configured —
      # before any method is selected: a client sending, say, both Basic
      # credentials and body credentials is rejected even when only one of
      # those methods is enabled on the server.
      #
      # Only real authentication mechanisms count towards the limit:
      #
      # * +:none+ is the absence of client authentication (a public client
      #   identifying itself with a bare +client_id+), not a mechanism of its
      #   own — RFC 7521 §4.2, for example, explicitly allows a +client_id+
      #   next to a client assertion.
      # * Deprecated +client_credentials+ callable extractors are
      #   configuration adapters rather than registered methods, so they
      #   cannot count either; they keep the historical "first extractor that
      #   returns a uid wins" selection (see
      #   ClientAuthentication::LegacyCallable) for the deprecation window.
      def validate_client_authentication!(request)
        matched = 0

        Doorkeeper::ClientAuthentication.registered_methods.each_value do |method|
          next if method.name == :none
          next unless method.matches_request?(request)

          matched += 1

          # RFC 6749 §2.3 only forbids using more than one method, so bail out
          # on the second match instead of evaluating the remaining methods.
          raise Errors::MultipleClientAuthMethods if matched > 1
        end
      end

      def client_authentication_methods
        Doorkeeper.configuration.client_authentication_methods
      end

      def authorization_flows
        Doorkeeper.configuration.authorization_response_flows
      end

      def token_flows
        Doorkeeper.configuration.token_grant_flows
      end

      # [NOTE]: this will be removed in a newer versions of Doorkeeper.
      # For retro-compatibility only
      def available
        Doorkeeper.config.deprecated_token_grant_types_resolver
      end

      def build_fallback_strategy_class(grant_or_request_type)
        strategy_class_name = grant_or_request_type.to_s.tr(" ", "_").camelize
        fallback_strategy = "Doorkeeper::Request::#{strategy_class_name}".constantize

        ::Kernel.warn <<~WARNING
          [DOORKEEPER] #{fallback_strategy} found using fallback, it must be
          registered using `Doorkeeper::GrantFlow.register(grant_flow_name, **options)`.
          This functionality will be removed in a newer versions of Doorkeeper.
        WARNING

        fallback_strategy
      rescue NameError
        raise Errors::InvalidTokenStrategy
      end
    end
  end
end
