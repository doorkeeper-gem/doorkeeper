module Doorkeeper
  class ApplicationsController < Doorkeeper::ApplicationController
    respond_to :html

    before_filter :authenticate_admin!

    def index
      @applications = Application.all
    end

    def new
      @application = Application.new
    end

    def create
      @application = Application.new(params[:application])
      if @application.save
        flash[:notice] = I18n.t('application_created', :scope => [:doorkeeper, :flashes])
        respond_with [:oauth, @application]
      else
        render :new
      end
    end

    def show
      @application = Application.find(params[:id])
    end

    def edit
      @application = Application.find(params[:id])
    end

    def update
      @application = Application.find(params[:id])
      if @application.update_attributes(params[:application])
        flash[:notice] = I18n.t('application_updated', :scope => [:doorkeeper, :flashes])
        respond_with [:oauth, @application]
      else
        render :edit
      end
    end

    def destroy
      @application = Application.find(params[:id])
      flash[:notice] = I18n.t('application_deleted', :scope => [:doorkeeper, :flashes]) if @application.destroy
      redirect_to oauth_applications_url
    end
  end
end
