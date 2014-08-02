module Doorkeeper
  module OAuth
    class ForbiddenTokenResponse < ErrorResponse
      def self.from_scope(scope, attributes = {})
        new(attributes.merge(scope: scope))
      end

      def initialize(attributes = {})
        super(attributes.merge(name: :invalid_scope, state: :forbidden))
        @scope = attributes[:scope]
      end

      def status
        :forbidden
      end

      def headers
        headers = super
        headers.delete 'WWW-Authenticate'
        headers
      end

      def description
        @description ||= I18n.translate @scope, scope: [:doorkeeper, :scopes]
      end
    end
  end
end
