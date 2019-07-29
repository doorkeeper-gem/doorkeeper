# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # This class handles a request from a device asking for a device code.
    # Defined on section 3.1 in the draft:
    # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15#section-3.1
    class DeviceRequest < BaseRequest
      attr_accessor :client, :server, :host_name
      validate :client, error: :invalid_client

      def initialize(server, client, host_name)
        @server = server
        @client = client
        @host_name = host_name
      end

      def authorize
        validate

        @response = if valid?
                      DeviceResponse.new(access_grant, host_name)
                    else
                      ErrorResponse.from_request(self)
                    end
      end

      private

      def validate_client
        client.present?
      end

      def access_grant
        @access_grant ||= AccessGrant.create!(access_grant_attributes)
      end

      def access_grant_attributes
        {
          application_id: client.id,
          expires_in: device_code_expires_in,
          user_code: unique_user_code,
          scopes: scopes.to_s,
        }
      end

      def device_code_expires_in
        Doorkeeper.configuration.device_code_expires_in
      end

      def unique_user_code
        10.times do
          user_code = generate_user_code
          return user_code unless AccessGrant
            .where("user_code = ? AND created_at >= ?",
                   user_code, device_code_expires_in.seconds.ago).exists?
        end
      end

      def generate_user_code
        user_code_format.split("-").map do |desc|
          Array.new(desc.to_i).map do
            if desc.end_with?("w")
              alphabet[SecureRandom.random_number(26)]
            else
              SecureRandom.random_number(10)
            end
          end.join
        end.join("-")
      end

      def alphabet
        @alphabet ||= ("A".."Z").to_a
      end

      def user_code_format
        if /\A(\d+[wd])(-\d+[wd])*\Z/.match?(Doorkeeper.configuration.user_code_format)
          Doorkeeper.configuration.user_code_format
        else
          "4w-4w"
        end
      end
    end
  end
end
