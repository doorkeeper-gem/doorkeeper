# frozen_string_literal: true

require "doorkeeper/client_authentication/credentials"
require "doorkeeper/client_authentication/fallback_method"
require "doorkeeper/client_authentication/method"
require "doorkeeper/client_authentication/registry"

module Doorkeeper
  # Registry of the OAuth client authentication methods (RFC 6749 §2.3)
  # Doorkeeper knows how to process. Each registered method is able to tell
  # whether it +matches_request?+ and how to +authenticate+ it into a
  # Credentials object.
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
