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

    validate :attributes,    :error => :invalid_request
    validate :client,        :error => :invalid_client
    validate :redirect_uri,  :error => :invalid_redirect_uri
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
      create_authorization if valid?
    end

    def access_token_exists?
      access_token.present? && access_token_scope_matches?
    end

    def deny
      self.error = :access_denied
    end

    def success_redirect_uri
      build_uri do |uri|
        query = uri.query.nil? ? "" : uri.query + "&"
        query << "code=#{token}"
        query << "&state=#{state}" if has_state?
        uri.query = query
      end
    end

    def invalid_redirect_uri
      build_uri do |uri|
        query = uri.query.nil? ? "" : uri.query + "&"
        query << "error=#{error}"
        query << "&state=#{state}" if has_state?
        uri.query = query
      end
    end

    def client
      @client ||= Application.find_by_uid(client_id)
    end

    def scopes
      Doorkeeper.configuration.scopes.with_names(*scope.split(" ")) if has_scope?
    end

    private

    def create_authorization
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

    def token
      @grant.token
    end

    def build_uri
      uri = URI.parse(redirect_uri)
      yield uri
      uri.to_s
    end

    def validate_attributes
      %w(response_type client_id redirect_uri).all? { |attr| send(attr).present? }
    end

    def validate_client
      !!client
    end

    def validate_redirect_uri
      uri = URI.parse(redirect_uri)
      return false unless uri.fragment.nil?
      return false if uri.scheme.nil?
      return false if uri.host.nil?
      client.is_matching_redirect_uri?(redirect_uri)
    end

    def validate_response_type
      response_type == "code"
    end

    def validate_scope
      return true unless has_scope?
      scope.present? && scope !~ /[\n|\r|\t]/ && scope.split(" ").all? { |s| Doorkeeper.configuration.scopes.exists?(s) }
    end

    def access_token
      AccessToken.accessible.where(:application_id => client.id, :resource_owner_id => resource_owner.id).first
    end

    def access_token_scope_matches?
      (access_token.scopes - scope.split(" ").map(&:to_sym)).empty?
    end
  end
end
