# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3 "none": a public client that authenticates with only a
      # client_id and no secret (in the request body, not the query string).
      class None
        def self.matches_request?(request)
          params = request.request_parameters.with_indifferent_access

          request.post? &&
            request.authorization.blank? &&
            params[:client_id].present? &&
            params[:client_secret].blank?
        end

        def self.authenticate(request)
          params = request.request_parameters.with_indifferent_access

          Doorkeeper::ClientAuthentication::Credentials.new(params[:client_id], nil)
        end
      end
    end
  end
end
