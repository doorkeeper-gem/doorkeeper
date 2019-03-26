# frozen_string_literal: true

module Doorkeeper
  module OAuth
    GRANT_TYPES = [
      AUTHORIZATION_CODE = "authorization_code".freeze,
      IMPLICIT = "implicit".freeze,
      PASSWORD = "password".freeze,
      CLIENT_CREDENTIALS = "client_credentials".freeze,
      REFRESH_TOKEN = "refresh_token".freeze,
    ].freeze
  end
end
