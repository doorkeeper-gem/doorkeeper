class Doorkeeper::AuthorizationsController < Doorkeeper::ApplicationController
  before_filter :authenticate_resource_owner!

  def new
    if authorization.valid?
      if authorization.access_token_exists?
        authorization.authorize
        redirect_to authorization.success_redirect_uri
      end
    elsif authorization.redirect_on_error?
      redirect_to authorization.invalid_redirect_uri
    else
      @error = authorization.error_response
      render :error
    end
  end

  def create
    if authorization.authorize
      redirect_to authorization.success_redirect_uri
    elsif authorization.redirect_on_error?
      redirect_to authorization.invalid_redirect_uri
    else
      @error = authorization.error_response
      render :error
    end
  end

  def destroy
    authorization.deny
    redirect_to authorization.invalid_redirect_uri
  end

  private

  def authorization_params
    params.has_key?(:authorization) ? params[:authorization] : params
  end

  def client
    @client ||= Doorkeeper::OAuth::Client.find(authorization_params[:client_id])
  end

  def authorization
    @authorization ||= Doorkeeper::OAuth::AuthorizationRequest.new(client, current_resource_owner, authorization_params)
  end
end
