# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3.1 "client_secret_basic": client credentials are sent
      # using HTTP Basic authentication.
      class ClientSecretBasic
        def self.matches_request?(request)
          request.authorization.present? &&
            request.authorization.downcase.start_with?("basic")
        end

        def self.authenticate(request)
          value = request.authorization.to_s.split(" ", 2).last
          client_id, client_secret = Base64.decode64(value.to_s).split(":", 2)

          return unless client_id.present? && client_secret.present?

          Doorkeeper::ClientAuthentication::Credentials.new(client_id, client_secret)
        end
      end
    end
  end
end
