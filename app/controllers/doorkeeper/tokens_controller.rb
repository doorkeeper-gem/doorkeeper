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
    rescue Errors::DoorkeeperError => error
      handle_invalid_request(error)
    end

  private

    def strategy
      @strategy ||= server.request params[:grant_type]
    end

    def handle_invalid_request(error)
      error_name = case error
        when Errors::InvalidRequestStrategy then :unsupported_grant_type
        when Errors::MissingRequestStrategy then :invalid_request
      end
      response = OAuth::ErrorResponse.new :name => error_name, :state => params[:state]
      render :json => response.body, :status => response.status
    end
  end
end
