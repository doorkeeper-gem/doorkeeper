# frozen_string_literal: true

module Doorkeeper
  class TokenInfoController < Doorkeeper::ApplicationMetalController
    def show
      if doorkeeper_token&.accessible?
        render json: doorkeeper_token_to_json, status: :ok
      else
        error = doorkeeper_token_error_response
        response.headers.merge!(error.headers)
        render json: error_to_json(error), status: error.status
      end
    end

    protected

    def doorkeeper_token_to_json
      doorkeeper_token
    end

    def error_to_json(error)
      error.body
    end

    # RFC 6750 §3.1: transmitting the access token by more than one method is
    # answered with invalid_request (400), not invalid_token (401). The helper
    # answers nil for such a request and keeps the error, so the response is
    # chosen here rather than by rescuing a raise.
    def doorkeeper_token_error_response
      if (error = @_doorkeeper_multiple_token_methods_error)
        OAuth::InvalidRequestResponse.new(reason: error.reason)
      else
        OAuth::InvalidTokenResponse.new
      end
    end
  end
end
