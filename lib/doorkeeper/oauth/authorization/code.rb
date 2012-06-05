module Doorkeeper
  module OAuth
    module Authorization
      class Code
        include URIBuilder

        attr_accessor :authorization, :grant

        def initialize(authorization)
          @authorization = authorization
        end

        def issue_token
          @grant ||= AccessGrant.create!(
            :application_id    => authorization.client.id,
            :resource_owner_id => authorization.resource_owner.id,
            :expires_in        => configuration.authorization_code_expires_in,
            :redirect_uri      => authorization.redirect_uri,
            :scopes            => authorization.scopes.to_s
          )
        end

        def callback
          uri_with_query(authorization.redirect_uri, {
            :code  => grant.token,
            :state => authorization.state
          })
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
