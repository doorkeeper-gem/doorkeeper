# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientCredentials
      class Validator
        include Validations
        include OAuth::Helpers

        validate :client, error: Errors::InvalidClient
        validate :client_confidential, error: Errors::InvalidClient
        validate :client_supports_grant_flow, error: Errors::UnauthorizedClient
        validate :scopes, error: Errors::InvalidScope

        def initialize(server, request)
          @server = server
          @request = request
          @client = request.client

          validate
        end

        private

        def validate_client
          @client.present?
        end

        # RFC 6749 Section 4.4: the client credentials grant "MUST only be used
        # by confidential clients". Registered public clients keep the
        # long-standing behaviour here, since a host application registered
        # them deliberately and may rely on it. A metadata document client is
        # different: nobody registered it, so a document naming "none" would
        # let whoever can host that document mint a token for a client of
        # their own, with this server's default scopes and no authentication
        # at all.
        def validate_client_confidential
          return true unless Doorkeeper::ClientIdMetadata.enabled?
          return true if @client.blank?
          return true unless Doorkeeper::ClientIdMetadata.url_client_id?(@client.uid)

          @client.application.confidential?
        end

        def validate_client_supports_grant_flow
          return if @client.blank?

          Doorkeeper.config.allow_grant_flow_for_client?(
            Doorkeeper::OAuth::CLIENT_CREDENTIALS,
            @client.application,
          )
        end

        def validate_scopes
          application_scopes = if @client.present?
                                 @client.application.scopes
                               else
                                 ""
                               end
          return true if @request.scopes.blank? && application_scopes.blank?

          ScopeChecker.valid?(
            scope_str: @request.scopes.to_s,
            server_scopes: @server.scopes,
            app_scopes: application_scopes,
            grant_type: Doorkeeper::OAuth::CLIENT_CREDENTIALS,
          )
        end
      end
    end
  end
end
