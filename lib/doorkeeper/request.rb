require 'doorkeeper/request/authorization_code'
require 'doorkeeper/request/client_credentials'
require 'doorkeeper/request/code'
require 'doorkeeper/request/password'
require 'doorkeeper/request/refresh_token'
require 'doorkeeper/request/token'

module Doorkeeper
  module Request
    extend self

    def authorization_strategy(strategy)
      get_strategy strategy, %w[code token]
    rescue NameError
      raise Errors::InvalidAuthorizationStrategy
    end

    def token_strategy(strategy)
      get_strategy strategy, %w[password client_credentials authorization_code refresh_token]
    rescue NameError
      raise Errors::InvalidTokenStrategy
    end

    def get_strategy(strategy, available)
      raise Errors::MissingRequestStrategy unless strategy.present?
      raise NameError unless available.include?(strategy.to_s)
      "Doorkeeper::Request::#{strategy.to_s.camelize}".constantize
    end
  end
end
