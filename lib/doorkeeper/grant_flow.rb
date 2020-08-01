# frozen_string_literal: true

require "doorkeeper/grant_flow/flow"
require "doorkeeper/grant_flow/fallback_flow"
require "doorkeeper/grant_flow/registry"

module Doorkeeper
  module GrantFlow
    extend Registry

    register(
      :implicit,
      response_type_matches: "token",
      response_mode_matches: %w[fragment form_post],
      response_type_strategy: Doorkeeper::Request::Token,
    )

    register(
      :authorization_code,
      response_type_matches: "code",
      response_mode_matches: %w[query fragment form_post],
      response_type_strategy: Doorkeeper::Request::Code,
      grant_type_matches: "authorization_code",
      grant_type_strategy: Doorkeeper::Request::AuthorizationCode,
    )

    register(
      :client_credentials,
      grant_type_matches: "client_credentials",
      grant_type_strategy: Doorkeeper::Request::ClientCredentials,
    )

    register(
      :password,
      grant_type_matches: "password",
      grant_type_strategy: Doorkeeper::Request::Password,
    )

    register(
      :refresh_token,
      grant_type_matches: "refresh_token",
      grant_type_strategy: Doorkeeper::Request::RefreshToken,
    )
  end
end
