# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      class None
        def self.matches_request?(request)
          !request.authorization && request.request_parameters[:client_id] && !request.request_parameters[:client_secret]
        end

        def authenticate(request)
          Doorkeeper::ClientAuthentication::Credentials.new(
            request.request_parameters[:client_id], nil
          )
        end
      end
    end
  end
end
