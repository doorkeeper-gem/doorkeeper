module Doorkeeper
  class ApplicationsController < Doorkeeper::ApplicationController
    layout 'doorkeeper/admin'
    respond_to :html

    before_filter :authenticate_admin!
    before_filter :set_application, only: [:show, :edit, :update, :destroy]

    def index
      @applications = Application.all
    end

    def new
      @application = Application.new
    end

    def create
      @application = Application.new(application_params)
      if @application.save
        flash[:notice] = I18n.t(:notice, scope: [:doorkeeper, :flash, :applications, :create])
        respond_with [:oauth, @application]
      else
        render :new
      end
    end

    def update
      if @application.update_attributes(application_params)
        flash[:notice] = I18n.t(:notice, scope: [:doorkeeper, :flash, :applications, :update])
        respond_with [:oauth, @application]
      else
        render :edit
      end
    end

    def destroy
      flash[:notice] = I18n.t(:notice, scope: [:doorkeeper, :flash, :applications, :destroy]) if @application.destroy
      redirect_to oauth_applications_url
    end

    private

    def set_application
      @application = Application.find(params[:id])
    end

    def application_params
      if params.respond_to?(:permit)
        params.require(:application).permit(:name, :redirect_uri)
      else
        params[:application].slice(:name, :redirect_uri) rescue nil
      end
    end
  end
end
