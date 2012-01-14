module Doorkeeper::OAuth
  class AuthorizationRequest
    include Doorkeeper::Validations
    include Doorkeeper::OAuth::Authorization::URIBuilder

    ATTRIBUTES = [
      :response_type,
      :client_id,
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
    attr_accessor :resource_owner, :error

    def initialize(resource_owner, attributes)
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @resource_owner = resource_owner
      @scope          ||= Doorkeeper.configuration.default_scope_string
      validate
    end

    def authorize
      return false unless valid?
      @authorization = authorization_method.new(self)
      @authorization.issue_token
    end

    def access_token_exists?
      access_token.present? && access_token.accessible? && access_token_scope_matches?
    end

    def deny
      self.error = :access_denied
    end

    def success_redirect_uri
      @authorization.callback
    end

    def invalid_redirect_uri
      uri_builder = is_token_request? ? :uri_with_fragment : :uri_with_query
      send(uri_builder, redirect_uri, {
        :error => error,
        :error_description => error_description,
        :state => state
      })
    end

    def redirect_on_error?
      (error != :invalid_redirect_uri) && (error != :invalid_client)
    end

    def client
      @client ||= Application.find_by_uid(client_id)
    end

    def scopes
      Doorkeeper.configuration.scopes.with_names(*scope.split(" ")) if has_scope?
    end

    private

    def has_scope?
      Doorkeeper.configuration.scopes.all.present?
    end

    def validate_attributes
      response_type.present?
    end

    def validate_client
      !!client
    end

    def validate_redirect_uri
      if redirect_uri
        uri = URI.parse(redirect_uri)
        return false unless uri.fragment.nil?
        return false if uri.scheme.nil?
        return false if uri.host.nil?
        client.is_matching_redirect_uri?(redirect_uri)
      end
    end

    def validate_response_type
      is_code_request? || is_token_request?
    end

    def validate_scope
      return true unless has_scope?
      scope.present? && scope !~ /[\n|\r|\t]/ && scope.split(" ").all? { |s| Doorkeeper.configuration.scopes.exists?(s) }
    end

    def is_code_request?
      response_type == "code"
    end

    def is_token_request?
      response_type == "token"
    end

    def access_token
      AccessToken.accessible.where(:application_id => client.id, :resource_owner_id => resource_owner.id).first
    end

    def access_token_scope_matches?
      (access_token.scopes - scope.split(" ").map(&:to_sym)).empty?
    end

    def error_description
      I18n.translate error, :scope => [:doorkeeper, :errors, :messages]
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
