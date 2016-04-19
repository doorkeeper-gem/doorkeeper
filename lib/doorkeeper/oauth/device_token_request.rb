module Doorkeeper
  module OAuth
    class DeviceTokenRequest
      include Validations
      include OAuth::RequestConcern

      validate :client,           error: :invalid_client
      validate :grant_exists,     error: :authorization_declined
      validate :grant,            error: :code_expired
      validate :polling_interval, error: :slow_down
      validate :authorized,       error: :authorization_pending

      attr_accessor :server, :grant, :client, :access_token

      def initialize(server, grant, client)
        @server = server
        @client = client
        @grant  = grant
      end

      private

      def before_successful_response
        grant.transaction do
          grant.lock!
          raise Errors::InvalidGrantReuse if grant.revoked?

          grant.revoke
          find_or_create_access_token(grant.application,
                                      grant.resource_owner_id,
                                      grant.scopes,
                                      server)
        end
      end

      def validate_client
        !!client
      end

      def validate_grant_exists
        grant && grant.application_id == client.id
      end

      def validate_grant
        grant.accessible?
      end

      def validate_authorized
        grant.resource_owner_id.present?
      end

      def validate_polling_interval
        return false if grant.too_fast?
        grant.polled
      end
    end
  end
end
