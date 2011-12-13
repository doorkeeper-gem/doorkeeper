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
          @access_token ||= AccessToken.create!({
            :application_id    => authorization.client.id,
            :resource_owner_id => authorization.resource_owner.id,
            :scopes            => authorization.scopes.to_s,
            :expires_in        => configuration.access_token_expires_in,
            :use_refresh_token => false
          })
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
