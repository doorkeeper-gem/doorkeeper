# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class ClientSecretPost
        def self.matches_request?(request)
          request.method.upcase === "POST" && request.request_parameters[:client_id].present? && request.request_parameters[:client_secret].present?
        end

        def self.authenticate(request)
          client_id = request.request_parameters[:client_id]
          client_secret = request.request_parameters[:client_secret]

          Doorkeeper::ClientAuthentication::Credentials.new(
            client_id,
            client_secret
          )
        end
      end
    end
  end
end
