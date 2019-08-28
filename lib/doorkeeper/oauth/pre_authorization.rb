# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PreAuthorization
      include Validations

      validate :client_id,             error: :invalid_request
      validate :client,                error: :invalid_client
      validate :redirect_uri,          error: :invalid_redirect_uri
      validate :params,                error: :invalid_request
      validate :response_type,         error: :unsupported_response_type
      validate :scopes,                error: :invalid_scope
      validate :code_challenge_method, error: :invalid_code_challenge_method
      validate :client_supports_grant_flow, error: :unauthorized_client

      attr_reader :server, :client_id, :client, :redirect_uri, :response_type, :state,
                  :code_challenge, :code_challenge_method, :missing_param

      def initialize(server, attrs = {})
        @server                = server
        @client_id             = attrs[:client_id]
        @response_type         = attrs[:response_type]
        @redirect_uri          = attrs[:redirect_uri]
        @scope                 = attrs[:scope]
        @state                 = attrs[:state]
        @code_challenge        = attrs[:code_challenge]
        @code_challenge_method = attrs[:code_challenge_method]
      end

      def authorizable?
        valid?
      end

      def validate_client_supports_grant_flow
        Doorkeeper.configuration.allow_grant_flow_for_client?(grant_type, client.application)
      end

      def scopes
        Scopes.from_string scope
      end

      def scope
        @scope.presence || (server.default_scopes.presence && build_scopes)
      end

      def error_response
        is_implicit_flow = response_type == "token"

        if error == :invalid_request
          OAuth::InvalidRequestResponse.from_request(self, response_on_fragment: is_implicit_flow)
        else
          OAuth::ErrorResponse.from_request(self, response_on_fragment: is_implicit_flow)
        end
      end

      def as_json(attributes = {})
        return pre_auth_hash.merge(attributes.to_h) if attributes.respond_to?(:to_h)

        pre_auth_hash
      end

      private

      def build_scopes
        client_scopes = client.scopes
        if client_scopes.blank?
          server.default_scopes.to_s
        else
          (server.default_scopes & client_scopes).to_s
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

      def validate_redirect_uri
        return false if redirect_uri.blank?

        Helpers::URIChecker.valid_for_authorization?(
          redirect_uri,
          client.redirect_uri
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
        server.authorization_response_types.include?(response_type)
      end

      def validate_scopes
        Helpers::ScopeChecker.valid?(
          scope_str: scope,
          server_scopes: server.scopes,
          app_scopes: client.scopes,
          grant_type: grant_type
        )
      end

      def grant_type
        response_type == "code" ? AUTHORIZATION_CODE : IMPLICIT
      end

      def validate_code_challenge_method
        code_challenge.blank? ||
          (code_challenge_method.present? && code_challenge_method =~ /^plain$|^S256$/)
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
        }
      end
    end
  end
end
