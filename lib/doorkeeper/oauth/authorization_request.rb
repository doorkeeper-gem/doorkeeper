module Doorkeeper::OAuth
  class AuthorizationRequest
    include Doorkeeper::Validations
    include Doorkeeper::OAuth::Authorization::URIBuilder
    include Doorkeeper::OAuth::Helpers

    ATTRIBUTES = [
      :response_type,
      :redirect_uri,
      :scope,
      :state
    ]

    validate :client,        :error => :invalid_client
    validate :redirect_uri,  :error => :invalid_redirect_uri
    validate :attributes,    :error => :invalid_request
    validate :response_type, :error => :unsupported_response_type
    validate :scope,         :error => :invalid_scope

    attr_accessor *ATTRIBUTES
    attr_accessor :resource_owner, :client, :error

    def initialize(client, resource_owner, attributes)
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @resource_owner = resource_owner
      @client         = client
      validate
    end

    def authorize
      return false unless valid?
      @authorization = authorization_method.new(self)
      @authorization.issue_token
    end

    def access_token_exists?
      Doorkeeper::AccessToken.matching_token_for(client, resource_owner, scopes).present?
    end

    def deny
      self.error = :access_denied
    end

    def error_response
      Doorkeeper::OAuth::ErrorResponse.from_request(self)
    end

    def success_redirect_uri
      @authorization.callback
    end

    def invalid_redirect_uri
      uri_builder = is_token_request? ? :uri_with_fragment : :uri_with_query
      send(uri_builder, redirect_uri, error_response.attributes)
    end

    def redirect_on_error?
      (error != :invalid_redirect_uri) && (error != :invalid_client)
    end

    def scopes
      @scopes ||= if scope.present?
        Doorkeeper::OAuth::Scopes.from_string(scope)
      else
        Doorkeeper.configuration.default_scopes
      end
    end

    def client_id
      client.uid
    end

    private

    def validate_attributes
      response_type.present?
    end

    def validate_client
      !!client
    end

    def validate_redirect_uri
      return false unless redirect_uri
      URIChecker.valid_for_authorization?(redirect_uri, client.redirect_uri)
    end

    def validate_response_type
      is_code_request? || is_token_request?
    end

    def validate_scope
      return true unless scope.present?
      ScopeChecker.valid?(scope, configuration.scopes)
    end

    def is_code_request?
      response_type == "code"
    end

    def is_token_request?
      response_type == "token"
    end

    def configuration
      Doorkeeper.configuration
    end

    def authorization_method
      klass = is_code_request? ? "Code" : "Token"
      "Doorkeeper::OAuth::Authorization::#{klass}".constantize
    end
  end
end
