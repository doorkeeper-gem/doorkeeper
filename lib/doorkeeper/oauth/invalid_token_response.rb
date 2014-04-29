module Doorkeeper
  module OAuth
    class InvalidTokenResponse < ErrorResponse
      def self.from_access_token(access_token, attributes = {})
        reason = case
          when access_token.try(:revoked?)
            :revoked
          when access_token.try(:expired?)
            :expired
          else
            :unknown
          end

        new(attributes.merge(reason: reason))
      end

      def initialize(attributes = {})
        super(attributes.merge(name: :invalid_token, state: :unauthorized))
        @reason = attributes[:reason] || :unknown
      end

      def description
        @description ||= I18n.translate @reason, scope: [:doorkeeper, :errors, :messages, :invalid_token]
      end
    end
  end
end
