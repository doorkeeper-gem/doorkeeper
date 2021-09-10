# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class ForbiddenTokenResponse < ErrorResponse
      def self.from_scopes(scopes, attributes = {})
        new(attributes.merge(scopes: scopes))
      end

      def initialize(attributes = {})
        super(attributes.merge(name: :invalid_scope, state: :forbidden))
        @scopes = attributes[:scopes]
      end

      def status
        :forbidden
      end

      def headers
        headers = super
        headers.delete "WWW-Authenticate"
        headers
      end

      def description
        @description ||= I18n.t("doorkeeper.errors.messages.forbidden_token.missing_scope",
                                oauth_scopes: @scopes.map(&:to_s).join(" "),)
      end

      protected

      def exception_class
        Doorkeeper::Errors::TokenForbidden
      end
    end
  end
end
