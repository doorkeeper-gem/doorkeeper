module Doorkeeper
  class Server
    attr_accessor :context

    def initialize(context = nil)
      @context = context
    end

    def authorization_request(strategy)
      klass = Request.authorization_strategy strategy
      klass.build self
    end

    def token_request(strategy)
      klass = Request.token_strategy strategy
      klass.build self
    end

    # TODO: context should be the request
    def parameters
      context.request.parameters
    end

    def client
      return unless client_credentials.present?
      uid, secret = client_credentials.values
      Doorkeeper.client.oauth_authenticate uid, secret
    end

    def client_via_uid
      Doorkeeper.client.find_for_oauth_authentication parameters[:client_id]
    end

    def current_resource_owner
      context.send :current_resource_owner
    end

    def current_refresh_token
      Doorkeeper::AccessToken.by_refresh_token(parameters[:refresh_token])
    end

    def grant
      Doorkeeper::AccessGrant.authenticate(parameters[:code])
    end

    # TODO: Use configuration and evaluate proper context on block
    def resource_owner
      context.send :resource_owner_from_credentials
    end

    def config
      Doorkeeper.configuration
    end

  private

    def credential_methods
      config.client_credentials_methods
    end

    def client_credentials
      OAuth::Client::Credentials.from_request context.request, *credential_methods
    end
  end
end
