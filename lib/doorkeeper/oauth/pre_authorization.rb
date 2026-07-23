# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PreAuthorization
      include Validations

      validate :client_id, error: Errors::InvalidRequest
      validate :client, error: Errors::InvalidClient
      validate :redirect_uri, error: Errors::InvalidRedirectUri
      validate :client_supports_grant_flow, error: Errors::UnauthorizedClient
      validate :resource_owner_authorize_for_client, error: Errors::AccessDenied
      validate :params, error: Errors::InvalidRequest
      validate :response_type, error: Errors::UnsupportedResponseType
      validate :response_mode, error: Errors::UnsupportedResponseMode
      validate :scopes, error: Errors::InvalidScope
      validate :code_challenge, error: Errors::InvalidRequest
      validate :code_challenge_method, error: Errors::InvalidCodeChallengeMethod

      attr_reader :client, :code_challenge, :code_challenge_method, :missing_param,
                  :redirect_uri, :resource_owner, :response_type, :state,
                  :authorization_response_flow, :response_mode, :custom_access_token_attributes,
                  :invalid_request_reason

      def initialize(server, parameters = {}, resource_owner = nil)
        @server = server
        @client_id = parameters[:client_id]
        @response_type = parameters[:response_type]
        @response_mode = parameters[:response_mode]
        @redirect_uri = parameters[:redirect_uri]
        @scope = parameters[:scope]
        @state = parameters[:state]
        @code_challenge = parameters[:code_challenge]
        @code_challenge_method = parameters[:code_challenge_method]
        @resource_owner = resource_owner
        @custom_access_token_attributes = parameters.slice(*Doorkeeper.config.custom_access_token_attributes).to_h
      end

      def authorizable?
        valid?
      end

      def scopes
        Scopes.from_string(scope)
      end

      def scope
        @scope.presence || (server.default_scopes.presence && build_scopes)
      end

      def error_response
        # RFC 9207: authorization error responses advertise the issuer. Passing
        # the configured issuer here (nil when unset) scopes the iss parameter
        # to the authorization endpoint only.
        if error == Errors::InvalidRequest
          OAuth::InvalidRequestResponse.from_request(
            self,
            response_on_fragment: response_on_fragment?,
            issuer: Doorkeeper.config.issuer,
          )
        else
          OAuth::ErrorResponse.from_request(
            self,
            response_on_fragment: response_on_fragment?,
            issuer: Doorkeeper.config.issuer,
          )
        end
      end

      def as_json(_options = nil)
        pre_auth_hash
      end

      def form_post_response?
        response_mode == "form_post"
      end

      private

      attr_reader :client_id, :server

      def build_scopes
        client_scopes = client.scopes
        if client_scopes.blank?
          server.default_scopes.to_s
        else
          server.default_scopes.allowed(client_scopes).to_s
        end
      end

      def validate_client_id
        @missing_param = :client_id if client_id.blank?
        @missing_param.nil?
      end

      def validate_client
        @client = OAuth::Client.find(client_id)
        @client.present?
      end

      def validate_client_supports_grant_flow
        Doorkeeper.config.allow_grant_flow_for_client?(grant_type, client.application)
      end

      def validate_resource_owner_authorize_for_client
        # The `authorize_resource_owner_for_client` config option is used for this validation
        client.application.authorized_for_resource_owner?(@resource_owner)
      end

      def validate_redirect_uri
        return false if redirect_uri.blank?

        Helpers::URIChecker.valid_for_authorization?(
          redirect_uri,
          client.redirect_uri,
        )
      end

      def validate_params
        @missing_param = if response_type.blank?
                           :response_type
                         elsif @scope.blank? && server.default_scopes.blank?
                           :scope
                         end

        @missing_param.nil?
      end

      def validate_response_type
        server.authorization_response_flows.any? do |flow|
          if flow.matches_response_type?(response_type)
            @authorization_response_flow = flow
            true
          end
        end
      end

      def validate_response_mode
        if response_mode.blank?
          @response_mode = authorization_response_flow.default_response_mode
          return true
        end

        authorization_response_flow.matches_response_mode?(response_mode)
      end

      def validate_scopes
        Helpers::ScopeChecker.valid?(
          scope_str: scope,
          server_scopes: server.scopes,
          app_scopes: client.scopes,
          grant_type: grant_type,
        )
      end

      def validate_code_challenge
        return true unless Doorkeeper.config.force_pkce?
        # PKCE (RFC 7636) protects the exchange of an authorization code, so
        # a code_challenge is only required from response types that issue one
        # ("code" and code-carrying hybrid types like "code id_token"). For
        # response types that never issue a code (e.g. "token" or an OIDC
        # extension's "id_token"), there is no token-endpoint exchange where a
        # verifier could ever be checked, so requiring a challenge would
        # reject those requests over a parameter that cannot be validated.
        return true unless code_issuing_response_type?
        return true if code_challenge.present?

        @invalid_request_reason = :invalid_code_challenge
        false
      end

      def validate_code_challenge_method
        return true unless Doorkeeper.config.access_grant_model.pkce_supported?

        code_challenge.blank? ||
          (code_challenge_method.present? && Doorkeeper.config.pkce_code_challenge_methods_supported.include?(code_challenge_method))
      end

      def response_on_fragment?
        return response_type == "token" if response_mode.nil?

        response_mode == "fragment"
      end

      def grant_type
        response_type == "code" ? AUTHORIZATION_CODE : IMPLICIT
      end

      # Whether the requested response type issues an authorization code.
      # Multi-valued response types (OIDC hybrid flows registered by
      # extensions, e.g. "code id_token") are space-delimited per OAuth 2.0
      # Multiple Response Type Encoding Practices, so a token-wise check also
      # covers response types Doorkeeper itself does not ship.
      def code_issuing_response_type?
        response_type.to_s.split.include?("code")
      end

      def pre_auth_hash
        {
          client_id: client.uid,
          redirect_uri: redirect_uri,
          state: state,
          response_type: response_type,
          scope: scope,
          client_name: client.name,
          status: I18n.t("doorkeeper.pre_authorization.status"),
        }.reverse_merge(custom_access_token_attributes.symbolize_keys)
      end
    end
  end
end
