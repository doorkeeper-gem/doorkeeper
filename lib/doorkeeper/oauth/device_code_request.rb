# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # This class handles a request from a device asking for a token for device code.
    # Defined on section 3.4 in the draft:
    # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15#section-3.4
    class DeviceCodeRequest < BaseRequest
      attr_accessor :grant, :client, :server, :access_token
      validate :client, error: :invalid_client
      validate :grant, error: :invalid_grant

      def initialize(server, access_grant, client)
        @server = server
        @grant = access_grant
        @client = client
        @grant_type = Doorkeeper::OAuth::DEVICE_CODE
      end

      def before_successful_response
        check_user_interaction!

        grant.transaction do
          grant.lock!
          grant.revoke
          generate_access_token
        end
        super
      end

      private

      def check_user_interaction!
        raise Errors::AccessDenied if grant.revoked?
        raise Errors::SlowDown if polling_to_fast?

        grant.update last_polling_at: Time.now

        raise Errors::AuthorizationPending unless grant.user_code.nil?
      end

      def polling_to_fast?
        grant.last_polling_at &&
          grant.last_polling_at > Doorkeeper.configuration.device_code_polling_interval.seconds.ago
      end

      def generate_access_token
        find_or_create_access_token(grant.application,
                                    grant.resource_owner_id,
                                    grant.scopes,
                                    server)
      end

      def validate_client
        client.present?
      end

      def validate_grant
        return false unless grant && grant.application_id == client.id

        !grant.expired?
      end
    end
  end
end
