class Doorkeeper::AuthorizedApplicationsController < Doorkeeper::ApplicationController
  before_filter :authenticate_resource_owner!

  def index
    @applications = Doorkeeper::Application.authorized_for(current_resource_owner)
  end

  def destroy
    Doorkeeper::AccessToken.revoke_all_for params[:id], current_resource_owner
    redirect_to oauth_authorized_applications_url, :notice => I18n.t(:notice, :scope => [:doorkeeper, :flash, :authorized_applications, :destroy])
  end
end
