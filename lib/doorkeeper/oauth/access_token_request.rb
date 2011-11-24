module Doorkeeper::OAuth
  class AccessTokenRequest
    module ValidationMethods
      def validate_required_attributes
        :invalid_request if !code.present? || !grant_type.present? || !redirect_uri.present?
      end

      def validate_client
        :invalid_client unless client
      end

      def validate_grant
        :invalid_grant if grant.nil? || grant.expired? || grant.application_id != client.id || grant.redirect_uri != redirect_uri
      end

      def validate_grant_type
        :unsupported_grant_type unless grant_type == "authorization_code"
      end
    end

    include Doorkeeper::Validations
    include ValidationMethods

    ATTRIBUTES = [
      :client_id,
      :client_secret,
      :grant_type,
      :code,
      :redirect_uri,
    ]

    validate :required_attributes
    validate :client
    validate :grant
    validate :grant_type

    attr_accessor *ATTRIBUTES

    def initialize(code, attributes = {})
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      validate
    end

    def authorize
      create_access_token if valid?
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

    def client
      @client ||= Application.find_by_uid_and_secret(@client_id, @client_secret)
    end

    def create_access_token
      @access_token = AccessToken.create!(
        :application_id    => client.uid,
        :resource_owner_id => grant.resource_owner_id,
      )
    end
  end
end
