# frozen_string_literal: true

module Doorkeeper
  class AuthorizedApplicationsController < Doorkeeper::ApplicationController
    before_action :authenticate_resource_owner!
    before_action :validate_resource_owner

    def index
      @applications = Doorkeeper.config.application_model.authorized_for(current_resource_owner)

      respond_to do |format|
        format.html
        format.json { render json: @applications, current_resource_owner: current_resource_owner }
      end
    end

    def destroy
      Doorkeeper.config.application_model.revoke_tokens_and_grants_for(
        params[:id],
        current_resource_owner,
      )

      respond_to do |format|
        format.html do
          redirect_to oauth_authorized_applications_url, notice: I18n.t(
            :notice, scope: %i[doorkeeper flash authorized_applications destroy],
          )
        end

        format.json { head :no_content }
      end
    end

    private

    # `authenticate_resource_owner!` hands the request to the host
    # application's `resource_owner_authenticator` block, which is expected to
    # halt the request itself — redirect to a sign-in page, raise, render —
    # when nobody is signed in. A block that merely answers nil halts nothing:
    # the library default (no block configured) logs a warning and answers
    # nil, and so does any block written as a bare lookup such as
    # `User.find_by(id: session[:user_id])`.
    #
    # Both actions here scope their work to `current_resource_owner`, and a
    # nil owner is not "no scope" — it is the scope of the records that have
    # no resource owner, which is what the client credentials flow issues.
    # #index would list every application holding one and #destroy would
    # revoke them, for a caller that never authenticated. So refuse the
    # request rather than treat "nobody" as an owner. Only this controller is
    # guarded; `authenticate_resource_owner!` itself is left alone because
    # AuthorizationsController shapes its own response around the owner.
    def validate_resource_owner
      head :unauthorized unless current_resource_owner
    end
  end
end
