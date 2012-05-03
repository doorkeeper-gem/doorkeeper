require 'active_model'

module Doorkeeper
  module OAuth
    class ClientCredentialsRequest
      class Response
        include ActiveModel::Serializers::JSON

        self.include_root_in_json = false

        delegate :token, :expires_in, :scopes_string, :to => :@token
        alias    :access_token :token
        alias    :scope :scopes_string

        def initialize(token)
          @token = token
        end

        def attributes
          {
            'access_token' => token,
            'token_type'   => token_type,
            'expires_in'   => expires_in,
            'scope'        => scopes_string
          }
        end

        def status
          :success
        end

        def token_type
          'bearer'
        end

        def headers
          { 'Cache-Control' => 'no-store', 'Pragma' => 'no-cache' }
        end
      end
    end
  end
end
