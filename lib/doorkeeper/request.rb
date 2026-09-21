# frozen_string_literal: true

module Doorkeeper
  module Request
    class << self
      # Resolves the strategy that answers the given response_type at the
      # authorization endpoint.
      #
      # A response_type no registered authorization flow handles is refused
      # rather than turned into a class name: `constantize` would otherwise
      # resolve any constant under Doorkeeper::Request, token endpoint
      # strategies (`password`, `client_credentials`, `refresh_token`,
      # `authorization_code`) included, none of which can answer an
      # authorization request.
      def authorization_strategy(response_type)
        response_type = response_type.to_s

        grant_flow = authorization_flows.detect do |flow|
          flow.matches_response_type?(response_type)
        end

        raise Errors::InvalidTokenStrategy unless grant_flow

        # [NOTE]: this will be removed in a newer versions of Doorkeeper.
        # For retro-compatibility only: flows declared through the deprecated
        # Config#calculate_authorization_response_types hook are built as
        # GrantFlow::FallbackFlow and carry no strategy, so the class is looked
        # up by name - but only for a response type the server does declare.
        grant_flow.response_type_strategy || build_fallback_strategy_class(response_type)
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
