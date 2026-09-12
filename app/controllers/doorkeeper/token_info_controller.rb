# frozen_string_literal: true

module Doorkeeper
  class TokenInfoController < Doorkeeper::ApplicationMetalController
    include Doorkeeper::Rails::Helpers

    def show
      if doorkeeper_token&.accessible? && doorkeeper_token_dpop_binding_satisfied?
        render json: doorkeeper_token_to_json, status: :ok
      else
        error = doorkeeper_error
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
  end
end
