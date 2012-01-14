module Doorkeeper
  module OAuth
    module Authorization
      class Token
        include URIBuilder

        attr_accessor :authorization

        def initialize(authorization)
          @authorization = authorization
        end

        def callback
          uri_with_fragment(authorization.redirect_uri, {
            :access_token => access_token.token,
            :token_type   => access_token.token_type,
            :expires_in   => access_token.time_left,
            :state => authorization.state
          })
        end

        def issue_token
          if access_token_exists?
            access_token
          else
            AccessToken.create!({
              :application_id    => authorization.client.id,
              :resource_owner_id => authorization.resource_owner.id,
              :scopes            => authorization.scope,
              :expires_in        => configuration.access_token_expires_in,
              :use_refresh_token => false
            })
          end
        end

        def access_token_exists?
          access_token.present? && access_token.accessible? && access_token_scope_matches?
        end

        def access_token_scope_matches?
          (access_token.scopes - authorization.scope.split(" ").map(&:to_sym)).empty?
        end

        def access_token
          AccessToken.accessible.where(:application_id => authorization.client.id, :resource_owner_id => authorization.resource_owner.id).first
        end

        def configuration
          Doorkeeper.configuration
        end
      end
    end
  end
end
