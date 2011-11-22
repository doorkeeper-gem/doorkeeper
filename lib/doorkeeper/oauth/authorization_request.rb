module Doorkeeper::OAuth
  class AuthorizationRequest

    module ValidationMethods
      def error_type
        case
          when missing_required_attributes? then :invalid_request
          when invalid_client?              then :invalid_client
          when invalid_redirect_uri?        then :invalid_redirect_uri
          when invalid_response_type?       then :unsupported_response_type
        end
      end

      def invalid_redirect_uri?
        client.redirect_uri != redirect_uri
      end

      def invalid_client?
        !client
      end

      def missing_required_attributes?
        !response_type.present? || !client_id.present? || !redirect_uri.present?
      end

      def invalid_response_type?
        response_type != "code"
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

    attr_accessor *ATTRIBUTES
    attr_accessor :resource_owner, :error

    def initialize(resource_owner, attributes)
      @resource_owner = resource_owner
      @grant          = nil
      @error          = nil
      ATTRIBUTES.each do |attribute|
        instance_variable_set("@#{attribute}", attributes[attribute])
      end
    end

    def authorize
      build_authorization if valid?
    end

    def valid?
      @error = error_type
      @error.nil?
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

    def build_authorization
      @grant = AccessGrant.create!(
        :application_id => client.id,
        :resource_owner_id => resource_owner.id,
        :expires_in => DEFAULT_EXPIRATION_TIME
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
