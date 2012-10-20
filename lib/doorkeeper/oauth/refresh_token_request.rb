module Doorkeeper::OAuth
  # TODO: Validate if refresh token is enabled in config
  class RefreshTokenRequest
    include Doorkeeper::Validations

    ATTRIBUTES = [
      :code,
      :refresh_token
    ]

    validate :attributes,   :error => :invalid_request
    validate :client,       :error => :invalid_client
    validate :grant,        :error => :invalid_grant

    attr_accessor *ATTRIBUTES
    attr_accessor :client

    def initialize(client, attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @client = client
      validate
    end

    def authorize
      if valid?
        revoke_base_token
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
      @access_token ||= Doorkeeper::AccessToken.matching_token_for client, base_token.resource_owner_id, base_token.scopes
    end

    def token_type
      "bearer"
    end

    def error_response
      Doorkeeper::OAuth::ErrorResponse.from_request(self)
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

    def base_token
      @base_token ||= token_via_refresh_token
    end

    def token_via_refresh_token
      Doorkeeper::AccessToken.by_refresh_token(refresh_token)
    end

    def create_access_token
      @access_token = Doorkeeper::AccessToken.create!({
        :application_id    => client.id,
        :resource_owner_id => base_token.resource_owner_id,
        :scopes            => base_token.scopes_string,
        :expires_in        => configuration.access_token_expires_in,
        :use_refresh_token => refresh_token_enabled?
      })
    end

    def validate_attributes
      refresh_token.present?
    end

    def refresh_token_enabled?
      configuration.refresh_token_enabled?
    end

    def validate_client
      !!client
    end

    def validate_grant
      return false unless base_token && base_token.application_id == client.id
      !base_token.revoked?
    end

    def configuration
      Doorkeeper.configuration
    end
  end
end
