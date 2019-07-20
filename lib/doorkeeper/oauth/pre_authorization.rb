# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PreAuthorization
      include Validations

      validate :response_type, error: :unsupported_response_type
      validate :client, error: :invalid_client
      validate :scopes, error: :invalid_scope
      validate :redirect_uri, error: :invalid_redirect_uri
      validate :code_challenge_method, error: :invalid_code_challenge_method

      attr_accessor :server, :client, :response_type, :redirect_uri, :state,
                    :code_challenge, :code_challenge_method
      attr_writer   :scope

      def initialize(server, client, attrs = {})
        @server                = server
        @client                = client
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

      def scopes
        Scopes.from_string scope
      end

      def scope
        @scope.presence || build_scopes
      end

      def error_response
        OAuth::ErrorResponse.from_request(self)
      end

      def as_json(attributes = {})
        return pre_auth_hash.merge(attributes.to_h) if attributes.respond_to?(:to_h)

        pre_auth_hash
      end

      private

      def build_scopes
        client_scopes = client.application.scopes
        if client_scopes.blank?
          server.default_scopes.to_s
        else
          (server.default_scopes & client_scopes).to_s
        end
      end

      def validate_response_type
        server.authorization_response_types.include? response_type
      end

      def validate_client
        client.present?
      end

      def validate_scopes
        return true if scope.blank?

        Helpers::ScopeChecker.valid?(
          scope_str: scope,
          server_scopes: server.scopes,
          app_scopes: client.application.scopes,
          grant_type: grant_type
        )
      end

      def grant_type
        response_type == "code" ? AUTHORIZATION_CODE : IMPLICIT
      end

      def validate_redirect_uri
        return false if redirect_uri.blank?

        Helpers::URIChecker.valid_for_authorization?(
          redirect_uri,
          client.redirect_uri
        )
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
