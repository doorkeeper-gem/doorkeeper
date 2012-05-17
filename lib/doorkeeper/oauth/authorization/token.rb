module Doorkeeper
  module OAuth
    module Authorization
      class Token
        include URIBuilder

        attr_accessor :authorization, :access_token

        def initialize(authorization)
          @authorization = authorization
        end

        def callback
          uri_with_fragment(authorization.redirect_uri, {
            :access_token => access_token.token,
            :token_type   => access_token.token_type,
            :expires_in   => access_token.expires_in,
            :state => authorization.state
          })
        end

        def issue_token
          return @access_token unless @access_token.nil?
          @access_token = AccessToken.new
          @access_token.application_id    = authorization.client.id,
          @access_token.resource_owner_id = authorization.resource_owner.id,
          @access_token.scopes            = authorization.scopes.to_s,
          @access_token.expires_in        = configuration.access_token_expires_in,
          @access_token.use_refresh_token = false
          @access_token.save
          @access_token
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
