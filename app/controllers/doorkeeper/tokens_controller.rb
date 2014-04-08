module Doorkeeper
  class TokensController < ActionController::Metal
    include Helpers::Controller
    include Helpers::Filter
    include ActionController::RackDelegation
    include ActionController::Instrumentation
    include ActionController::Head

    def create
      response = strategy.authorize
      self.headers.merge! response.headers
      self.response_body = response.body.to_json
      self.status        = response.status
    rescue Errors::DoorkeeperError => e
      handle_token_exception e
    end

    def destroy
      if doorkeeper_token
        doorkeeper_token.revoke
        head :no_content
      else
        head :not_found
      end
    end

  private

    def strategy
      @strategy ||= server.token_request params[:grant_type]
    end
  end
end
