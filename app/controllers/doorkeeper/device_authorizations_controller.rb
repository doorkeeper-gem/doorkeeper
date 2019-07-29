# frozen_string_literal: true

module Doorkeeper
  # The DeviceAuthorizationsController implements the oauth device grant draft as specified here:
  # https://tools.ietf.org/html/draft-ietf-oauth-device-flow-15
  class DeviceAuthorizationsController < Doorkeeper::ApplicationController
    before_action :authenticate_resource_owner!
    before_action :set_access_grant_by_code, only: :show
    before_action :set_access_grant, only: %i[update destroy]

    def index
      @access_grant = AccessGrant.new
      respond_to do |format|
        format.html
        format.json { head :no_content }
      end
    end

    def show
      return handle_errors unless @access_grant&.accessible?

      respond_to do |format|
        format.html
        format.json { render json: @access_grant }
      end
    end

    def update
      return handle_errors unless @access_grant&.accessible?

      if user_authenticated_device?
        accept_grant
      else
        render_update_error
      end
    end

    def destroy
      revoke_grant
      respond_to do |format|
        format.html { redirect_to oauth_device_index_path }
        format.json { head :no_content }
      end
    end

    private

    def user_authenticated_device?
      params[:user_code].present? &&
        @access_grant.user_code == params[:user_code]
    end

    def handle_errors
      errors = t("doorkeeper.errors.messages.user_code.unknown") if @access_grant.blank?
      errors = t("doorkeeper.errors.messages.user_code.expired") if @access_grant&.expired?
      errors = t("doorkeeper.errors.messages.user_code.revoked") if @access_grant&.revoked?
      respond_to do |format|
        format.html { redirect_to oauth_device_index_path, notice: errors }
        format.json { render json: { errors: errors }, status: :unprocessable_entity }
      end
    end

    def accept_grant
      @access_grant.update user_code: nil, resource_owner_id: current_resource_owner.id
      notice = I18n.t(:success, scope: i18n_scope(:update))
      respond_to do |format|
        format.html { redirect_to oauth_device_index_path, notice: notice }
        format.json { render json: @access_grant }
      end
    end

    def revoke_grant
      return unless @access_grant.update(revoked_at: Time.now)

      flash[:notice] = I18n.t(:success, scope: i18n_scope(:destroy))
    end

    def render_update_error
      respond_to do |format|
        errors = I18n.t(:unknown_user_code, scope: i18n_scope(:update))
        format.html { redirect_to oauth_device_url(@access_grant.token), notice: errors }
        format.json { render json: { errors: errors }, status: :unprocessable_entity }
      end
    end

    def set_access_grant
      @access_grant = AccessGrant.find_by token: params[:id]
    end

    def set_access_grant_by_code
      @access_grant = AccessGrant.where(user_code: params[:id]).order("created_at DESC").first
    end

    def i18n_scope(action)
      %i[doorkeeper flash device_code] << action
    end
  end
end
