# frozen_string_literal: true

require "doorkeeper/client_authentication/flow"
require "doorkeeper/client_authentication/registry"

module Doorkeeper
  module ClientAuthentication
    extend Registry

    register(
      :none,
      mechanism: Doorkeeper::ClientAuthentication::Mechanisms::None,
      authenticates_client: false
    )

    register(
      :client_secret_post,
      mechanism: Doorkeeper::ClientAuthentication::Mechanisms::ClientSecretPost,
    )

    register(
      :client_secret_basic,
      mechanism: Doorkeeper::ClientAuthentication::Mechanisms::ClientSecretBasic,
    )
  end
end
