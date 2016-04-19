module Doorkeeper
  module OAuth
    module PreAuthorizationMixin
      extend ActiveSupport::Concern

      include Validations

      included do
        validate :client, error: :invalid_client
        validate :scopes, error: :invalid_scope

        attr_accessor :server, :client
        attr_writer   :scope
      end

      def authorizable?
        valid?
      end

      def scopes
        Scopes.from_string scope
      end

      def scope
        @scope.presence || server.default_scopes.to_s
      end

      def error_response
        OAuth::ErrorResponse.from_request(self)
      end

      private

      def validate_client
        client.present?
      end

      def validate_scopes
        return true unless scope.present?
        Helpers::ScopeChecker.valid?(
          scope,
          server.scopes,
          client.application.scopes
        )
      end
    end
  end
end
