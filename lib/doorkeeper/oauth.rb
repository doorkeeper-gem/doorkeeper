# frozen_string_literal: true

module Doorkeeper
  module OAuth
    GRANT_TYPES = [
      AUTHORIZATION_CODE = "authorization_code",
      IMPLICIT = "implicit",
      PASSWORD = "password",
      CLIENT_CREDENTIALS = "client_credentials",
      REFRESH_TOKEN = "refresh_token",
      JWT_BEARER = "urn:ietf:params:oauth:grant-type:jwt-bearer",
    ].freeze
  end
end
