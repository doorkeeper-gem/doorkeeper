class Doorkeeper::TokensController < Doorkeeper::ApplicationController
  def create
    response.headers.merge!({
      'Pragma'        => 'no-cache',
      'Cache-Control' => 'no-store',
    })
    if strategy.authorize
      render :json => strategy.request.authorization
    else
      render :json => strategy.request.error_response, :status => strategy.request.error_response.status
    end
  rescue Doorkeeper::Errors::InvalidRequestStrategy
    error = Doorkeeper::OAuth::ErrorResponse.new :name => :unsupported_grant_type
    render :json => error, :status => error.status
  rescue Doorkeeper::Errors::MissingRequestStrategy
    error = Doorkeeper::OAuth::ErrorResponse.new :name => :invalid_request
    render :json => error, :status => error.status
  end

  private

  def server
    @server ||= Doorkeeper::Server.new(self)
  end

  def strategy
    @strategy ||= server.request params[:grant_type]
  end
end
