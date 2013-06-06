module Doorkeeper
  module OAuth
    class InvalidTokenResponse < ErrorResponse
      def self.from_access_token(access_token, attributes = {})
        reason = case
          when access_token.nil?
            :unknown
          when access_token.respond_to?(:revoked?) && access_token.revoked?
            :revoked
          when access_token.respond_to?(:expired?) && access_token.expired?
            :expired
          end

        new(attributes.merge(:reason => reason))
      end

      def initialize(attributes = {})
        super(attributes.merge(:name => :invalid_token, :state => :unauthorized))
        @reason = attributes[:reason] || :unknown
      end

      def description
        @description ||= I18n.translate @reason, :scope => [:doorkeeper, :errors, :messages, :invalid_token]
      end

      def authenticate_info
        %{Bearer error="#{body[:error]}", error_description="#{body[:error_description]}"}
      end

      def headers
        super.merge('WWW-Authenticate' => authenticate_info)
      end
    end
  end
end
