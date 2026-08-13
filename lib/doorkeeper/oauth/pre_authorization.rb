# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class PreAuthorization
      include Validations

      # The validations that identify the client and its redirect URI. None of
      # them depend on the resource owner, so the authorization endpoint can
      # run them before authenticating anyone and spare the user a login that
      # can only end on an error page. RFC 6749 Section 4.1.2.1 (Section 4.2.2.1
      # for the implicit flow) asks for the resource owner to be informed when
      # the client_id is missing or invalid, and Section 3.1.2.4 asks the same
      # for the redirect URI; running these first is what lets the endpoint
      # inform them without a detour through the login form.
      CLIENT_VALIDATIONS = %i[client_id client redirect_uri].freeze

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
      validate :resource_indicators, error: Errors::InvalidTarget
      # Runs after :resource_indicators so a malformed target is still answered
      # as the client's error rather than the server's.
      validate :resource_indicator_storage, error: Errors::ServerError

      attr_reader :client, :code_challenge, :code_challenge_method, :missing_param,
                  :redirect_uri, :resource_owner, :response_type, :state,
                  :authorization_response_flow, :response_mode, :custom_access_token_attributes,
                  :invalid_request_reason, :resource_indicators

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
        @raw_resource_indicators = parameters[:resource]
      end

      def authorizable?
        valid?
      end

      # Runs only CLIENT_VALIDATIONS, in declared order, so a request
      # from an unknown client or with an invalid redirect URI can be refused
      # without a resource owner. Error precedence matches a full #validate
      # run because these are the first validations declared.
      def client_valid?
        @error = nil
        @missing_param = nil

        self.class.validations.each do |validation|
          next unless CLIENT_VALIDATIONS.include?(validation[:attribute])

          @error = validation[:options][:error] unless send("validate_#{validation[:attribute]}")
          break if @error
        end

        @error.nil?
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
          server.default_scopes.common(client_scopes).to_s
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

        return false unless @missing_param.nil?

        # A structured `scope` (e.g. `scope[a]=b`, parsed by Rack into a Hash)
        # is malformed (RFC 6749 §3.3). Reject it here — before validate_scopes
        # reaches Scopes.from_string — so the authorization endpoint answers
        # invalid_request instead of letting the raised error surface as a 500.
        # Set a reason so the error_description is not translated from nil.
        return true if scope_param_well_formed?

        @invalid_request_reason = :unknown
        false
      end

      def scope_param_well_formed?
        @scope.nil? || @scope.is_a?(String)
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

      def validate_resource_indicators
        validator = Doorkeeper.config.resource_indicator_validator
        # When no validator is configured, resource indicators are ignored (feature disabled)
        return true unless validator

        @resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client,
        )
        true
      rescue Errors::InvalidTarget
        false
      end

      # A client asking for a resource this server cannot record the audience
      # of is a misconfiguration — resource_indicator_validator is set, but the
      # `resource` column the doorkeeper:resource_indicators generator adds is
      # not there. Issuing the grant would raise MissingResourceColumn out of
      # Authorization::Code, which the authorization endpoint does not rescue,
      # so the misconfiguration reached the client as a 500. Answering
      # server_error here instead matches what the token endpoint already makes
      # of the same exception, and RFC 6749 Section 4.1.2.1 lists server_error
      # among the errors returned through the redirection URI.
      #
      # Only requests that actually ask for a resource are refused: without the
      # parameter there is nothing to record, and a misconfigured server would
      # otherwise stop authorizing anyone at all.
      def validate_resource_indicator_storage
        return true if @resource_indicators.blank?

        ResourceIndicatorValidator.storage_ready?
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
