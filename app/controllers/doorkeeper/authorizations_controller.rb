class Doorkeeper::AuthorizationsController < Doorkeeper::ApplicationController
  before_filter :authenticate_resource_owner!

  def new
    render :error unless authorization.valid?
  end

  def create
    if authorization.authorize
      redirect_to authorization.success_redirect_uri
    else
      render :error
    end
  end

  def destroy
    authorization.deny
    redirect_to authorization.invalid_redirect_uri
  end

  private

  def authorization
    @authorization ||= Doorkeeper::OAuth::AuthorizationRequest.new(current_resource_owner, params)
  end
end
