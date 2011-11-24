module Doorkeeper::OAuth
  class AuthorizationRequest
    include Doorkeeper::Validations

    module ValidationMethods
      def validate_required_attributes
        :invalid_request if !response_type.present? || !client_id.present? || !redirect_uri.present?
      end

      def validate_client
        :invalid_client unless client
      end

      def validate_redirect_uri
        :invalid_redirect_uri unless client.redirect_uri == redirect_uri
      end

      def validate_response_type
        :unsupported_response_type unless response_type == "code"
      end
    end

    include ValidationMethods

    DEFAULT_EXPIRATION_TIME = 600

    ATTRIBUTES = [
      :response_type,
      :client_id,
      :redirect_uri,
      :scope,
      :state
    ]

    validate :required_attributes
    validate :client
    validate :redirect_uri
    validate :response_type

    attr_accessor *ATTRIBUTES
    attr_accessor :resource_owner, :error

    def initialize(resource_owner, attributes)
      ATTRIBUTES.each { |attr| instance_variable_set("@#{attr}", attributes[attr]) }
      @resource_owner = resource_owner
      @grant          = nil
      validate
    end

    def authorize
      create_authorization if valid?
    end

    def deny
      self.error = :access_denied
    end

    def success_redirect_uri
      build_uri do |uri|
        query = "code=#{token}"
        query << "&state=#{state}" if has_state?
        uri.query = query
      end
    end

    def invalid_redirect_uri
      build_uri { |uri| uri.query = "error=#{error}" }
    end

    def client
      @client ||= Application.find_by_uid(client_id)
    end

    private

    def create_authorization
      @grant = AccessGrant.create!(
        :application_id    => client.id,
        :resource_owner_id => resource_owner.id,
        :expires_in        => DEFAULT_EXPIRATION_TIME,
        :redirect_uri      => redirect_uri
      )
    end

    def has_state?
      state.present?
    end

    def token
      @grant.token
    end

    def build_uri
      uri = URI.parse(client.redirect_uri)
      yield uri
      uri.to_s
    end
  end
end
