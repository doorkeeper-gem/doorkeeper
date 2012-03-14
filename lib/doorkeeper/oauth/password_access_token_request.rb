# coding: utf-8

# TODO: refactor to DRY up, this is very similar to AccessTokenRequest
#
# - it validates the owner is not null (should it verify it is valid?)
# - it doesn't need a redirect_uri
# - it should it verify grant_type is "password"

module Doorkeeper::OAuth
  class PasswordAccessTokenRequest
    include Doorkeeper::Validations

    ATTRIBUTES = [
      :client_id,
      :client_secret,
      :grant_type,
      :username,
      :password,
      :scope
    ]

    validate :attributes,     :error => :invalid_request
    validate :grant_type,     :error => :unsupported_grant_type
    validate :client,         :error => :invalid_client
    validate :resource_owner, :error => :invalid_resource_owner
    validate :scope,          :error => :invalid_scope

    attr_accessor *ATTRIBUTES
    attr_accessor :resource_owner

    def initialize(owner, attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @resource_owner = owner
      @scope ||= Doorkeeper.configuration.default_scope_string
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
      {
        'error' => error.to_s,
        'error_description' => error_description
      }
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

    def client
      @client ||= Doorkeeper::Application.find_by_uid_and_secret(@client_id, @client_secret)
    end

    def create_access_token
      @access_token = Doorkeeper::AccessToken.create!({
        :application_id     => client.id,
        :resource_owner_id  => resource_owner.id,
        :scopes             => @scope,
        :expires_in         => configuration.access_token_expires_in
      })
    end

    def has_scope?
      Doorkeeper.configuration.scopes.all.present?
    end

    def validate_attributes
      grant_type.present?
    end

    def validate_client
      !!client
    end

    def validate_scope
      return true unless has_scope?
      ScopeChecker.valid?(scope, configuration.scopes)
    end

    def validate_grant_type
      grant_type == 'password'
    end

    def validate_resource_owner
      !!resource_owner
    end

    def error_description
      I18n.translate error, :scope => [:doorkeeper, :errors, :messages]
    end

    def configuration
      Doorkeeper.configuration
    end
  end
end
