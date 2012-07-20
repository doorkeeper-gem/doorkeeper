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
      @application = Application.new(params[:application] || params[:doorkeeper_application].slice(:name, :redirect_uri))
      if @application.save
        flash[:notice] = "Application created"
        respond_with @application, :location => oauth_application_path(@application)
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
      if @application.update_attributes(params[:application] || params[:doorkeeper_application].slice(:name, :redirect_uri))
        flash[:notice] = "Application updated"
        respond_with @application, :location => oauth_application_path(@application)
      else
        render :edit
      end
    end

    def destroy
      @application = Application.find(params[:id])
      flash[:notice] = "Application deleted" if @application.destroy
      redirect_to oauth_applications_url
    end
  end
end
