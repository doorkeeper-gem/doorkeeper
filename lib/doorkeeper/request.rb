module Doorkeeper
  module Request
    class << self
      def authorization_strategy(response_type)
        get_strategy(response_type, authorization_response_types)
      rescue NameError
        raise Errors::InvalidAuthorizationStrategy
      end

      def token_strategy(grant_type)
        get_strategy(grant_type, token_grant_types)
      rescue NameError
        raise Errors::InvalidTokenStrategy
      end

      def get_strategy(grant_or_request_type, available)
        raise Errors::MissingRequestStrategy if grant_or_request_type.blank?
        raise NameError unless available.include?(grant_or_request_type.to_s)

        build_strategy_class(grant_or_request_type)
      end

      private

      def authorization_response_types
        Doorkeeper.configuration.authorization_response_types
      end

      def token_grant_types
        Doorkeeper.configuration.token_grant_types
      end

      def build_strategy_class(grant_or_request_type)
        strategy_class_name = grant_or_request_type.to_s.tr(' ', '_').camelize
        "Doorkeeper::Request::#{strategy_class_name}".constantize
      end
    end
  end
end
