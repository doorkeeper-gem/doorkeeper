# frozen_string_literal: true

module Doorkeeper
  module ClientAuthentication
    module Mechanisms
      class ClientSecretPost
        def self.matches_request?(request)
          request.method.upcase === "POST"
        end

        def authenticate(request)
          client_id = request.request_parameters[:client_id]
          client_secret = request.request_parameters[:client_secret]

          return unless client_id.present? && client_secret.present?

          Doorkeeper::ClientAuthentication::Credentials.new(
            client_id,
            client_secret
          )
        end
      end
    end
  end
end
