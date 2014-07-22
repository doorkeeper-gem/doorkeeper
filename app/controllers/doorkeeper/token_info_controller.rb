module Doorkeeper
  class TokenInfoController < ApplicationController
    def show
      if doorkeeper_token && doorkeeper_token.accessible?
        render json: doorkeeper_token, status: :ok
      else
        error = OAuth::ErrorResponse.new(name: :invalid_request)
        response.headers.merge!(error.headers)
        render json: error.body, status: error.status
      end
    end
  end
end
