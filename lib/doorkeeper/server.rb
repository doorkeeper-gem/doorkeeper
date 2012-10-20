module Doorkeeper
  class Server
    attr_accessor :context

    def initialize(context = nil)
      @context = context
    end

    # Available strategies:
    # :code, :token, :password, :client_credentials, :authorization_code, :refresh_token
    def strategy_for(strategy)
      "Doorkeeper::Request::#{strategy.to_s.camelize}".constantize
    rescue NameError
      raise Doorkeeper::Errors::InvalidRequestStrategy
    end

    def request(strategy)
      klass = strategy_for strategy
      klass.build self
    end

    # TODO: context should be the request
    def parameters
      context.request.parameters
    end

    def client
      @client ||= Doorkeeper::OAuth::Client.authenticate(credentials)
    end

    # TODO: Use configuration and evaluate proper context on block
    def resource_owner
      context.send :resource_owner_from_credentials
    end

    def credentials
      methods = Doorkeeper.configuration.client_credentials_methods
      @credentials ||= Doorkeeper::OAuth::Client::Credentials.from_request(context.request, *methods)
    end
  end
end
