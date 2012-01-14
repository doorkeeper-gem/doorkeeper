module Doorkeeper
  module OAuth
    module Authorization
      class Code
        DEFAULT_EXPIRATION_TIME = 600

        attr_accessor :client, :resource_owner, :redirect_uri, :scope, :state, :grant

        def initialize(client, resource_owner, redirect_uri, scope, state)
          @client         = client
          @resource_owner = resource_owner
          @redirect_uri   = redirect_uri
          @scope          = scope
          @state          = state
        end

        def issue_token
          @grant ||= AccessGrant.create!(
            :application_id    => client.id,
            :resource_owner_id => resource_owner.id,
            :expires_in        => DEFAULT_EXPIRATION_TIME,
            :redirect_uri      => redirect_uri,
            :scopes            => scope
          )
        end

        def callback
          uri_with_query(redirect_uri, {
            :code  => grant.token,
            :state => state
          })
        end

        # def error_callback
        #   uri_with_query(redirect_uri, {
        #     :error => error,
        #     :error_description => error_description,
        #     :state => state
        #   })
        # end

        # def error_description
        #   I18n.translate error, :scope => [:doorkeeper, :errors, :messages]
        # end
      end
    end
  end
end
