# frozen_string_literal: true

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
        strategy_class_name = if grant_or_request_type.to_s.start_with?(extension_grant_start)
                                "Extension::#{grant_or_request_type.to_s.split(":").last.camelize}"
                              else
                                grant_or_request_type.to_s.tr(" ", "_").camelize
                              end
        "Doorkeeper::Request::#{strategy_class_name}".constantize
      end

      def extension_grant_start
        "urn:ietf:params:oauth:grant-type"
      end
    end
  end
end
