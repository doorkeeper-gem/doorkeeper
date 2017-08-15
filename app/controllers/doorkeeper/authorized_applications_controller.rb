module Doorkeeper
  class AuthorizedApplicationsController < Doorkeeper::ApplicationController
    before_action :authenticate_resource_owner!

    def index
      @applications = Application.authorized_for(current_resource_owner)
    end

    def destroy
      application = Application.find_by_id(params[:id])
      if application.present?
        AccessToken.revoke_all_for application, current_resource_owner
        redirect_to oauth_authorized_applications_url, notice: I18n.t(:notice, scope: [:doorkeeper, :flash, :authorized_applications, :destroy])
      end
    end
  end
end
