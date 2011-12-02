module Doorkeeper::OAuth
  class AccessTokenRequest
    include Doorkeeper::Validations

    ATTRIBUTES = [
      :client_id,
      :client_secret,
      :grant_type,
      :code,
      :redirect_uri,
    ]

    validate :attributes, :error => :invalid_request
    validate :client,     :error => :invalid_client
    validate :grant,      :error => :invalid_grant
    validate :grant_type, :error => :unsupported_grant_type

    attr_accessor *ATTRIBUTES

    def initialize(attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      validate
    end

    def authorize
      if valid?
        revoke_grant
        create_access_token
      end
    end

    def authorization
      { 'access_token' => access_token,
        'token_type'   => token_type
      }
    end

    def valid?
      self.error.nil?
    end

    def access_token
      @access_token.token
    end

    def token_type
      "bearer"
    end

    def error_response
      { 'error' => error.to_s }
    end

    private

    def grant
      @grant ||= AccessGrant.find_by_token(@code)
    end

    def revoke_grant
      grant.revoke
    end

    def client
      @client ||= Application.find_by_uid_and_secret(@client_id, @client_secret)
    end

    def create_access_token
      @access_token = AccessToken.create!({
        :application_id    => client.id,
        :resource_owner_id => grant.resource_owner_id,
        :scopes            => grant.scopes_string,
        :expires_in        => configuration.access_token_expires_in,
      })
    end

    def validate_attributes
      code.present? && grant_type.present? && redirect_uri.present?
    end

    def validate_client
      !!client
    end

    def validate_grant
      grant && grant.accessible? && grant.application_id == client.id && grant.redirect_uri == redirect_uri
    end

    def validate_grant_type
      grant_type == "authorization_code"
    end

    def configuration
      Doorkeeper.configuration
    end
  end
end
