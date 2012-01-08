module Doorkeeper::OAuth
  class AuthorizationRequest
    include Doorkeeper::Validations

    DEFAULT_EXPIRATION_TIME = 600

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
      @grant          = nil
      @scope          ||= Doorkeeper.configuration.default_scope_string
      validate
    end

    def authorize
      return false unless valid?
      if is_code_request?
        create_access_grant_for_code_request
      elsif is_token_request?
        create_access_token_for_token_request
      end
    end

    def access_token_exists?
      access_token.present? && access_token.accessible? && access_token_scope_matches?
    end

    def deny
      self.error = :access_denied
    end

    def success_redirect_uri_for_code_request
      build_uri do |uri|
        query = uri.query.nil? ? "" : uri.query + "&"
        query << "code=#{authorization_code}"
        query << "&state=#{state}" if has_state?
        uri.query = query
      end
    end

    def invalid_redirect_uri_for_code_request
      build_uri do |uri|
        query = uri.query.nil? ? "" : uri.query + "&"
        query << "error=#{error}"
        query << "&error_description=#{CGI::escape(error_description)}"
        query << "&state=#{state}" if has_state?
        uri.query = query
      end
    end

    def success_redirect_uri_for_token_request
      build_uri do |uri|
        fragment = "access_token=#{access_token.token}"
        fragment << "&token_type=#{access_token.token_type}"
        fragment << "&expires_in=#{access_token.time_left}"
        fragment << "&state=#{state}" if has_state?
        uri.fragment = fragment
      end
    end

    def invalid_redirect_uri_for_token_request
      build_uri do |uri|
        fragment = "error=#{error}"
        fragment << "&error_description=#{CGI::escape(error_description)}"
        fragment << "&state=#{state}" if has_state?
        uri.fragment = fragment
      end
    end

    def success_redirect_uri
      if is_code_request?
        success_redirect_uri_for_code_request
      elsif is_token_request?
        success_redirect_uri_for_token_request
      end
    end

    def invalid_redirect_uri
      if is_token_request?
        invalid_redirect_uri_for_token_request
      else
        invalid_redirect_uri_for_code_request
      end
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

    def create_access_grant_for_code_request
      @grant = AccessGrant.create!(
        :application_id    => client.id,
        :resource_owner_id => resource_owner.id,
        :expires_in        => DEFAULT_EXPIRATION_TIME,
        :redirect_uri      => redirect_uri,
        :scopes            => scope
      )
    end

    def has_state?
      state.present?
    end

    def has_scope?
      Doorkeeper.configuration.scopes.all.present?
    end

    def authorization_code
      @grant.token
    end

    def build_uri
      uri = URI.parse(redirect_uri || client.redirect_uri)
      yield uri
      uri.to_s
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

    def create_access_token_for_token_request
      if access_token_exists?
        access_token
      else
        AccessToken.create!({
          :application_id    => client.id,
          :resource_owner_id => resource_owner.id,
          :scopes            => scope,
          :expires_in        => configuration.access_token_expires_in,
          :use_refresh_token => false
        }) 
      end
    end

    def error_description
      I18n.translate error, :scope => [:doorkeeper, :errors, :messages]
    end

    def configuration
      Doorkeeper.configuration
    end

  end
end
