require 'doorkeeper/grant_flow/flow'

module Doorkeeper
  module GrantFlow
    mattr_accessor :registered_flows
    self.registered_flows = {}

    module_function

    def register(name_or_flow, options = {})
      if name_or_flow.is_a? Doorkeeper::GrantFlow::Flow
        registered_flows[name_or_flow.name.to_sym] = name_or_flow
      else
        registered_flows[name_or_flow.to_sym] = Flow.new(name_or_flow, options)
      end
    end

    def get(name)
      registered_flows.fetch(name.to_sym)
    end
  end
end

Doorkeeper::GrantFlow.register(
  :implicit,
  response_type_matches: 'token',
  response_type_strategy: Doorkeeper::Request::Token
)

Doorkeeper::GrantFlow.register(
  :authorization_code,
  response_type_matches: 'code',
  response_type_strategy: Doorkeeper::Request::Code,
  grant_type_matches: 'authorization_code',
  grant_type_strategy: Doorkeeper::Request::AuthorizationCode
)

Doorkeeper::GrantFlow.register(
  :client_credentials,
  grant_type_matches: 'client_credentials',
  grant_type_strategy: Doorkeeper::Request::ClientCredentials
)

Doorkeeper::GrantFlow.register(
  :password,
  grant_type_matches: 'password',
  grant_type_strategy: Doorkeeper::Request::Password
)

Doorkeeper::GrantFlow.register(
  :refresh_token,
  grant_type_matches: 'refresh_token',
  grant_type_strategy: Doorkeeper::Request::RefreshToken
)
