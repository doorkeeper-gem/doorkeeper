# frozen_string_literal: true

module Doorkeeper
  class ApplicationsController < Doorkeeper::ApplicationController
    layout "doorkeeper/admin" unless Doorkeeper.configuration.api_only

    before_action :authenticate_admin!
    before_action :force_json_format, if: :api_only?
    before_action :set_application, only: %i[show edit update destroy]

    def index
      @applications = Doorkeeper.config.application_model.ordered_by(:created_at)

      respond_to do |format|
        format.html
        format.json { head :no_content }
      end
    end

    def show
      respond_to do |format|
        format.html
        format.json { render json: @application, as_owner: true }
      end
    end

    def new
      @application = Doorkeeper.config.application_model.new
    end

    def create
      @application = Doorkeeper.config.application_model.new(application_params)

      if @application.save
        respond_to do |format|
          format.html do
            flash[:notice] = I18n.t(:notice, scope: %i[doorkeeper flash applications create])
            flash[:application_secret] = @application.plaintext_secret

            redirect_to oauth_application_url(@application)
          end
          format.json { render json: @application, as_owner: true }
        end
      else
        respond_to do |format|
          format.html { render :new }
          format.json do
            errors = @application.errors.full_messages

            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end
    end

    def edit; end

    def update
      if @application.update(application_params)
        respond_to do |format|
          format.html do
            flash[:notice] = I18n.t(:notice, scope: i18n_scope(:update))

            redirect_to oauth_application_url(@application)
          end
          format.json { render json: @application, as_owner: true }
        end
      else
        respond_to do |format|
          format.html { render :edit }
          format.json do
            errors = @application.errors.full_messages

            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end
    end

    def destroy
      destroyed = @application.destroy

      respond_to do |format|
        format.html do
          flash[:notice] = I18n.t(:notice, scope: i18n_scope(:destroy)) if destroyed

          redirect_to oauth_applications_url
        end
        format.json { head :no_content }
      end
    end

    private

    def set_application
      @application = Doorkeeper.config.application_model.find(params[:id])
    end

    def application_params
      params.require(:doorkeeper_application)
        .permit(:name, :redirect_uri, :scopes, :confidential)
    end

    def i18n_scope(action)
      %i[doorkeeper flash applications] << action
    end

    def api_only?
      Doorkeeper.config.api_only
    end

    # In api_only mode this controller descends from ActionController::API,
    # which has no flash and renders no views — but Rails still negotiates a
    # format from the request, and only a client that names JSON explicitly
    # lands on the json branch. Measured on Rails 8.0: an absent Accept header
    # and a browser-like list such as "application/json, text/plain, */*"
    # (axios's default) both resolve to text/html, while a bare "*/*" (curl,
    # Net::HTTP, python-requests) resolves to Mime::ALL, which respond_to
    # answers with the first registered format — html in every action here.
    # Those requests therefore ran the html branch and raised on flash, after
    # create had already persisted the record and destroy had already deleted
    # it. Nothing needs negotiating when only JSON can be served, so pin the
    # format rather than leaving a branch registered that cannot run.
    def force_json_format
      request.format = :json
    end
  end
end
