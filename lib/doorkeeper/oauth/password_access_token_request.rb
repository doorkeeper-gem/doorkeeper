# coding: utf-8

# TODO: refactor to DRY up, this is very similar to AccessTokenRequest
module Doorkeeper::OAuth
  class PasswordAccessTokenRequest
    include Doorkeeper::Validations

    ATTRIBUTES = [
      :grant_type,
      :username,
      :password,
      :scope,
      :refresh_token
    ]

    validate :attributes,     :error => :invalid_request
    validate :grant_type,     :error => :unsupported_grant_type
    validate :client,         :error => :invalid_client
    validate :resource_owner, :error => :invalid_resource_owner
    validate :scope,          :error => :invalid_scope

    attr_accessor *ATTRIBUTES
    attr_accessor :resource_owner, :client

    def initialize(client, owner, attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @resource_owner = owner
      @client = client
      validate
    end

    def authorize
      if valid?
        find_or_create_access_token
      end
    end

    def authorization
      auth = {
        'access_token' => access_token.token,
        'token_type'   => access_token.token_type,
        'expires_in'   => access_token.expires_in,
      }
      auth.merge!({'refresh_token' => access_token.refresh_token}) if refresh_token_enabled?
      auth
    end

    def valid?
      self.error.nil?
    end

    def access_token
      @access_token
    end

    def token_type
      "bearer"
    end

    def error_response
      Doorkeeper::OAuth::ErrorResponse.from_request(self)
    end

    def scopes
      @scopes ||= if scope.present?
        Doorkeeper::OAuth::Scopes.from_string(scope)
      else
        Doorkeeper.configuration.default_scopes
      end
    end

    private

    def find_or_create_access_token
      if access_token
        access_token.expired? ? revoke_and_create_access_token : access_token
      else
        create_access_token
      end
    end

    def revoke_and_create_access_token
      access_token.revoke
      create_access_token
    end

    def revoke_base_token
      base_token.revoke
    end

    def create_access_token
      @access_token = Doorkeeper::AccessToken.create!({
        :application_id     => client.id,
        :resource_owner_id  => resource_owner.id,
        :scopes             => scopes.to_s,
        :expires_in         => configuration.access_token_expires_in,
        :use_refresh_token  => refresh_token_enabled?
      })
    end

    def validate_attributes
      grant_type.present?
    end

    def refresh_token_enabled?
      configuration.refresh_token_enabled?
    end

    def validate_client
      !!client
    end

    def validate_scope
      return true unless scope.present?
      ScopeChecker.valid?(scope, configuration.scopes)
    end

    def validate_grant_type
      grant_type == 'password'
    end

    def validate_resource_owner
      !!resource_owner
    end

    def configuration
      Doorkeeper.configuration
    end
  end
end
