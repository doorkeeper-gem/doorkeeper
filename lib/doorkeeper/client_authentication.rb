# frozen_string_literal: true

require "doorkeeper/client_authentication/credentials"
require "doorkeeper/client_authentication/fallback_mechanism"
require "doorkeeper/client_authentication/mechanism"
require "doorkeeper/client_authentication/registry"

module Doorkeeper
  module ClientAuthentication
    extend Registry

    register(
      :none,
      mechanism: Doorkeeper::OAuth::ClientAuthentication::None,
      authenticates_client: false
    )

    register(
      :client_secret_post,
      mechanism: Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost,
    )

    register(
      :client_secret_basic,
      mechanism: Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic,
    )
  end
end
