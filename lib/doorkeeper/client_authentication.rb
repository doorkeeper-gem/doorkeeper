# frozen_string_literal: true

require "doorkeeper/client_authentication/credentials"
require "doorkeeper/client_authentication/fallback_method"
require "doorkeeper/client_authentication/method"
require "doorkeeper/client_authentication/registry"

module Doorkeeper
  module ClientAuthentication
    extend Registry

    register(
      :none,
      Doorkeeper::OAuth::ClientAuthentication::None,
    )

    register(
      :client_secret_post,
      Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost,
    )

    register(
      :client_secret_basic,
      Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic,
    )
  end
end
