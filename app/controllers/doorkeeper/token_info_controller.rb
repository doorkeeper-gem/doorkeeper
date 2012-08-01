class Doorkeeper::TokenInfoController < Doorkeeper::ApplicationController

  def show
    if doorkeeper_token && doorkeeper_token.accessible?
      render :json => doorkeeper_token, :status => :ok
    else
      render :json => Doorkeeper::OAuth::ErrorResponse.new(:name => :invalid_request), :status => :unauthorized
    end 
  end

end
