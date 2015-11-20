module Doorkeeper
  class DevicesController < Doorkeeper::ApplicationController
    def create
      response = authorize_response
      self.headers.merge! response.headers
      self.response_body = response.body.to_json
      self.status        = response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception e
    end

    private

    def pre_auth
      @pre_auth ||= OAuth::DevicePreAuthorization.new(Doorkeeper.configuration,
                                                      server.client_via_uid,
                                                      params)
    end

    def strategy
      @strategy ||= server.token_request params[:grant_type]
    end

    def authorize_response
      @authorize_response ||= strategy.authorize
    end
  end
end
