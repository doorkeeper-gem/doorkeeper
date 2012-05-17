module Doorkeeper
  module OAuth
    module Authorization
      class Code
        include URIBuilder

        DEFAULT_EXPIRATION_TIME = 600

        attr_accessor :authorization, :grant

        def initialize(authorization)
          @authorization = authorization
        end

        def issue_token
          return @grant unless @grant.nil? 
          @grant                   = AccessGrant.new
          @grant.application_id    = authorization.client.id,
          @grant.resource_owner_id = authorization.resource_owner.id,
          @grant.expires_in        = DEFAULT_EXPIRATION_TIME,
          @grant.redirect_uri      = authorization.redirect_uri,
          @grant.scopes            = authorization.scopes.to_s
          @grant.save
          @grant
        end

        def callback
          uri_with_query(authorization.redirect_uri, {
            :code  => grant.token,
            :state => authorization.state
          })
        end
      end
    end
  end
end
