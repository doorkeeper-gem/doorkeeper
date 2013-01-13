module Doorkeeper
  module Request
    extend self

    # Available authorization strategies:
    # :code, :token
    def authorization_strategy(strategy)
      "Doorkeeper::OAuth::#{strategy.to_s.camelize}Request".constantize
    rescue NameError
      raise Errors::InvalidAuthorizationStrategy
    end

    # Available token strategies:
    # :password, :client_credentials, :authorization_code, :refresh_token
    def token_strategy(strategy)
      "Doorkeeper::OAuth::#{strategy.to_s.camelize}Request".constantize
    rescue NameError
      raise Errors::InvalidTokenStrategy
    end

    def get_strategy(strategy)
      raise Errors::MissingRequestStrategy unless strategy.present?
      "Doorkeeper::Request::#{strategy.to_s.camelize}".constantize
    end
  end
end
