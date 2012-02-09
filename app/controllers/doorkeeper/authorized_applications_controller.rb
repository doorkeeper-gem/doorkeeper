class Doorkeeper::AuthorizedApplicationsController < Doorkeeper::ApplicationController
  before_filter :authenticate_resource_owner!

  def index
    @applications = Application.authorized_for(current_resource_owner)
  end

  def destroy
    AccessToken.revoke_all_for params[:id], current_resource_owner
    redirect_to authorized_applications_path, :notice => "Application revoked."
  end
end
