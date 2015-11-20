module Doorkeeper
  module OAuth
    class DeviceCodeResponse
      attr_accessor :token

      def initialize(token)
        @token = token
      end

      def body
        {
          code: token.token,
          user_code: token.user_token,
          verification_url: configuration.device_verification_url,
          expires_in: token.expires_in,
          interval: configuration.device_polling_interval
        }.reject { |_, value| value.blank? }
      end

      def status
        :ok
      end

      def headers
        { 'Cache-Control' => 'no-store',
          'Pragma' => 'no-cache',
          'Content-Type' => 'application/json; charset=utf-8' }
      end

      private

      def configuration
        Doorkeeper.configuration
      end
    end
  end
end
