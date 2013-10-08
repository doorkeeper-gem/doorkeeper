require 'doorkeeper/request/authorization_code'
require 'doorkeeper/request/client_credentials'
require 'doorkeeper/request/code'
require 'doorkeeper/request/password'
require 'doorkeeper/request/refresh_token'
require 'doorkeeper/request/token'

module Doorkeeper
  module Request
    module_function

    def authorization_strategy(strategy)
      get_strategy strategy, Doorkeeper.configuration.authorization_response_types
    rescue NameError
      raise Errors::InvalidAuthorizationStrategy
    end

    def token_strategy(strategy)
      get_strategy strategy, Doorkeeper.configuration.token_grant_types
    rescue NameError
      raise Errors::InvalidTokenStrategy
    end

    def get_strategy(strategy, available)
      fail Errors::MissingRequestStrategy unless strategy.present?
      fail NameError unless available.include?(strategy.to_s)
      "Doorkeeper::Request::#{strategy.to_s.camelize}".constantize
    end
  end
end
