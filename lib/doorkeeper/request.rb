require 'doorkeeper/request/authorization_code'
require 'doorkeeper/request/client_credentials'
require 'doorkeeper/request/code'
require 'doorkeeper/request/password'
require 'doorkeeper/request/refresh_token'
require 'doorkeeper/request/token'

module Doorkeeper
  module Request
    module_function

    def authorization_strategy(response_type)
      fail Errors::MissingRequestStrategy unless response_type.present?

      flow = authorization_flows.detect do |f|
        f.matches_response_type?(response_type)
      end

      if flow
        flow.response_type_strategy
      else
        raise Errors::InvalidAuthorizationStrategy
      end
    end

    def token_strategy(grant_type)
      fail Errors::MissingRequestStrategy unless grant_type.present?

      flow = token_flows.detect do |f|
        f.matches_grant_type?(grant_type)
      end

      if flow
        flow.grant_type_strategy
      else
        raise Errors::InvalidTokenStrategy
      end
    end

    def authorization_flows
      Doorkeeper.configuration.authorization_response_flows
    end

    def token_flows
      Doorkeeper.configuration.token_grant_flows
    end
  end
end
