# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class RefreshTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :token_presence, error: :invalid_request
      validate :token,        error: :invalid_grant
      validate :client,       error: :invalid_client
      validate :client_match, error: :invalid_grant
      validate :scope,        error: :invalid_scope

      attr_accessor :access_token, :client, :credentials, :refresh_token,
                    :server
      attr_reader   :missing_param

      def initialize(server, refresh_token, credentials, parameters = {})
        @server = server
        @refresh_token = refresh_token
        @credentials = credentials
        @original_scopes = parameters[:scope] || parameters[:scopes]
        @refresh_token_parameter = parameters[:refresh_token]
        @client = load_client(credentials) if credentials
      end

      private

      def load_client(credentials)
        server_config.application_model.by_uid_and_secret(credentials.uid, credentials.secret)
      end

      def before_successful_response
        refresh_token.transaction do
          refresh_token.lock!
          raise Errors::InvalidGrantReuse if refresh_token.revoked?

          refresh_token.revoke unless refresh_token_revoked_on_use?
          create_access_token
        end
        super
      end

      def refresh_token_revoked_on_use?
        server_config.access_token_model.refresh_token_revoked_on_use?
      end

      def default_scopes
        refresh_token.scopes
      end

      def create_access_token
        @access_token = server_config.access_token_model.create!(access_token_attributes)
      end

      def access_token_attributes
        attrs = {
          application_id: refresh_token.application_id,
          scopes: scopes.to_s,
          expires_in: refresh_token.expires_in,
          use_refresh_token: true,
        }

        if Doorkeeper.config.polymorphic_resource_owner?
          attrs[:resource_owner] = refresh_token.resource_owner
        else
          attrs[:resource_owner_id] = refresh_token.resource_owner_id
        end

        attrs.tap do |attributes|
          if refresh_token_revoked_on_use?
            attributes[:previous_refresh_token] = refresh_token.refresh_token
          end
        end
      end

      def validate_token_presence
        @missing_param = :refresh_token if refresh_token.blank? && @refresh_token_parameter.blank?

        @missing_param.nil?
      end

      def validate_token
        refresh_token.present? && !refresh_token.revoked?
      end

      def validate_client
        return true if credentials.blank?

        client.present?
      end

      # @see https://tools.ietf.org/html/draft-ietf-oauth-v2-22#section-1.5
      #
      def validate_client_match
        return true if refresh_token.application_id.blank?

        client && refresh_token.application_id == client.id
      end

      def validate_scope
        if @original_scopes.present?
          ScopeChecker.valid?(
            scope_str: @original_scopes,
            server_scopes: refresh_token.scopes,
          )
        else
          true
        end
      end
    end
  end
end
