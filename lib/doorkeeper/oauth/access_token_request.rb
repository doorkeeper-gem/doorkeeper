module Doorkeeper::OAuth
  class AccessTokenRequest
    include Doorkeeper::Validations

    ATTRIBUTES = [
      :client_id,
      :client_secret,
      :grant_type,
      :code,
      :redirect_uri,
      :refresh_token,
    ]

    validate :attributes,   :error => :invalid_request
    validate :grant_type,   :error => :unsupported_grant_type
    validate :client,       :error => :invalid_client
    validate :grant,        :error => :invalid_grant
    validate :redirect_uri, :error => :invalid_grant

    attr_accessor *ATTRIBUTES

    def initialize(attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      validate
    end

    def authorize
      if valid?
        revoke_base_token
        create_access_token
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
      {
        'error' => error.to_s,
        'error_description' => error_description
      }
    end

    private

    def revoke_base_token
      base_token.revoke
    end

    def client
      @client ||= Application.find_by_uid_and_secret(@client_id, @client_secret)
    end

    def base_token
      @base_token ||= refresh_token? ? token_via_refresh_token : token_via_authorization_code
    end

    def token_via_authorization_code
      AccessGrant.find_by_token(code)
    end

    def token_via_refresh_token
      AccessToken.find_by_refresh_token(refresh_token)
    end

    def create_access_token
      @access_token = AccessToken.create!({
        :application_id    => client.id,
        :resource_owner_id => base_token.resource_owner_id,
        :scopes            => base_token.scopes_string,
        :expires_in        => configuration.access_token_expires_in,
        :use_refresh_token => refresh_token_enabled?
      })
    end

    def validate_attributes
      return false unless grant_type.present?
      if refresh_token_enabled? && refresh_token?
        refresh_token.present?
      else
        code.present? && redirect_uri.present?
      end
    end

    def refresh_token_enabled?
      configuration.refresh_token_enabled?
    end

    def refresh_token?
      grant_type == "refresh_token"
    end

    def validate_client
      !!client
    end

    def validate_grant
      return false unless base_token && base_token.application_id == client.id
      refresh_token? ? !base_token.revoked? : base_token.accessible?
    end

    def validate_redirect_uri
      refresh_token? ? true : base_token.redirect_uri == redirect_uri
    end

    def validate_grant_type
      %w(authorization_code refresh_token).include? grant_type
    end

    def error_description
      I18n.translate error, :scope => [:doorkeeper, :errors, :messages]
    end

    def configuration
      Doorkeeper.configuration
    end
  end
end
