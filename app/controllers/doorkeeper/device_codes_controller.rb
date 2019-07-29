# frozen_string_literal: true

module Doorkeeper
  # The DeviceAuthorizationsController implements the oauth device grant draft as specified here:
  # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15
  class DeviceCodesController < Doorkeeper::ApplicationMetalController
    def create
      headers.merge!(authorize_response.headers)
      render json: authorize_response.body,
             status: authorize_response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception(e)
    end

    private

    def client
      server.client
    end

    def authorize_response
      @authorize_response ||= strategy.authorize
    end

    def strategy
      @strategy ||= server.authorization_request "urn:ietf:params:oauth:grant-type:device"
    end
  end
end
