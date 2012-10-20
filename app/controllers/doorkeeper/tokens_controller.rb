module Doorkeeper
  class TokensController < ::Doorkeeper::ApplicationController
    def create
      response.headers.merge!({
        'Pragma'        => 'no-cache',
        'Cache-Control' => 'no-store',
      })
      if strategy.authorize
        render :json => strategy.request.authorization
      else
        error = strategy.request.error_response
        render :json => error.body, :status => error.status
      end
    rescue Errors::DoorkeeperError => e
      handle_token_exception e
    end

  private

    def strategy
      @strategy ||= server.token_request params[:grant_type]
    end
  end
end
