module Doorkeeper::OAuth
  class AuthorizationRequest
    DEFAULT_EXPIRATION_TIME = 600

    attr_reader :resource_owner, :options

    delegate :name, :uid, :to => :client, :prefix => true

    def initialize(resource_owner, options)
      @resource_owner = resource_owner
      @options        = options
      @grant          = nil
    end

    def authorize
      if valid?
        @grant = AccessGrant.create!(
          :application_id => client.id,
          :resource_owner_id => resource_owner.id,
          :expires_in => DEFAULT_EXPIRATION_TIME
        )
      end
    end

    def response_type
      options[:response_type]
    end

    def client_id
      options[:client_id]
    end

    def valid?
      has_response_type? &&
      has_client? &&
      redirect_uri_matches?
    end

    def token
      @grant.token
    end

    def redirect_uri
      build_uri { |uri| uri.query = "code=#{token}" }
    end

    def invalid_redirect_uri
      build_uri { |uri| uri.query = "error=#{error_name}" }
    end

    def error_name
      case
      when !has_response_type? then "invalid_request"
      end
    end

    private

    def has_response_type?
      response_type.present?
    end

    def has_client?
      client.present?
    end

    def has_redirect_uri?
      options[:redirect_uri].present?
    end

    def redirect_uri_mismatches?
      has_redirect_uri? and client.redirect_uri != options[:redirect_uri]
    end

    def redirect_uri_matches?
      redirect_uri_mismatches? ? raise(MismatchRedirectURI) : true
    end

    def client
      @client ||= Application.find_by_uid(options[:client_id])
    end

    def build_uri
      uri = URI.parse(client.redirect_uri)
      yield uri
      uri.to_s
    end
  end
end
