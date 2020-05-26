# frozen_string_literal: true

module Doorkeeper
  module Request
    class << self
      def authorization_strategy(response_type)
        grant_flow = authorization_flows.detect do |flow|
          flow.matches_response_type?(response_type)
        end

        if grant_flow
          grant_flow.response_type_strategy
        else
          # [NOTE]: this will be removed in a newer versions of Doorkeeper.
          # For retro-compatibility only
          fallback_strategy = build_fallback_strategy_class(response_type)

          ::Kernel.warn <<~WARNING
            [DOORKEEPER] #{fallback_strategy} found using fallback, it must be
            registered using `Doorkeeper::GrantFlow.register(name, **options)`.
            This functionality will be remove in a newer versions of Doorkeeper.
          WARNING

          fallback_strategy
        end
      end

      def token_strategy(grant_type)
        raise Errors::MissingRequiredParameter, :grant_type if grant_type.blank?

        grant_flow = token_flows.detect do |flow|
          flow.matches_grant_type?(grant_type)
        end

        raise Errors::InvalidTokenStrategy unless grant_flow

        grant_flow.grant_type_strategy
      end

      private

      def authorization_flows
        Doorkeeper.configuration.authorization_response_flows
      end

      def token_flows
        Doorkeeper.configuration.token_grant_flows
      end

      def build_fallback_strategy_class(grant_or_request_type)
        strategy_class_name = grant_or_request_type.to_s.tr(" ", "_").camelize
        "Doorkeeper::Request::#{strategy_class_name}".constantize
      end
    end
  end
end
