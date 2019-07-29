# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # This class generates a response for a device asking for a device code.
    # Defined on section 3.2 in the draft:
    # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15#section-3.2
    class DeviceResponse < BaseResponse
      include OAuth::Helpers

      attr_accessor :access_grant, :host_name

      def initialize(access_grant, host_name)
        @access_grant = access_grant
        @host_name = host_name
      end

      def status
        200
      end

      def body
        {
          "device_code" => access_grant.token,
          "user_code" => access_grant.user_code,
          "verification_uri" => "#{host_name}/oauth/device",
          "verification_uri_complete" => "#{host_name}/oauth/device/#{access_grant.user_code}",
          "expires_in" => access_grant.expires_in,
          "interval" => Doorkeeper.configuration.device_code_polling_interval,
        }.reject { |_, value| value.blank? }
      end

      def headers
        {
          "Cache-Control" => "no-store",
          "Pragma" => "no-cache",
          "Content-Type" => "application/json; charset=utf-8",
        }
      end
    end
  end
end
