require 'doorkeeper/request/authorization_code'
require 'doorkeeper/request/client_credentials'
require 'doorkeeper/request/assertion'
require 'doorkeeper/request/code'
require 'doorkeeper/request/password'
require 'doorkeeper/request/refresh_token'
require 'doorkeeper/request/token'

module Doorkeeper
  module Request
    extend self

    # Available authorization strategies:
    # :code, :token
    def authorization_strategy(strategy)
      get_strategy strategy
    rescue NameError
      raise Errors::InvalidAuthorizationStrategy
    end

    # Available token strategies:
    # :password, :client_credentials, :authorization_code, :refresh_token
    def token_strategy(strategy)
      get_strategy strategy
    rescue NameError
      raise Errors::InvalidTokenStrategy
    end

    def get_strategy(strategy)
      raise Errors::MissingRequestStrategy unless strategy.present?
      "Doorkeeper::Request::#{strategy.to_s.camelize}".constantize
    end
  end
end
