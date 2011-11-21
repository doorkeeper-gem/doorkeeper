module Doorkeeper::OAuth
  class AccessTokenRequest
    DEFAULT_EXPIRATION_TIME = 2.days

    def initialize(code, options)
      @code          = code
      @client_id     = options[:client_id]
      @client_secret = options[:client_secret]
    end

    def authorize
      if valid?
        @access_token = AccessToken.create!(
          :application_id => client.uid,
          :resource_owner_id => grant.resource_owner_id,
          :expires_at => DateTime.now + DEFAULT_EXPIRATION_TIME
        )
      end
    end

    def authorization
      { 'access_token' => access_token,
        'token_type'   => token_type
      }
    end

    def valid?
      grant && client
    end

    def access_token
      @access_token.token
    end

    def token_type
      "bearer"
    end

    private

    def grant
      @grant ||= AccessGrant.find_by_token(@code)
    end

    def client
      @client ||= Application.find_by_uid_and_secret(@client_id, @client_secret)
    end
  end
end
