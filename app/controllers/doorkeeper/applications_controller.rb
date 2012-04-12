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
      flash[:notice] = "Application created" if @application.save
      respond_with @application
    end

    def show
      @application = Application.find(params[:id])
    end

    def edit
      @application = Application.find(params[:id])
    end

    def update
      @application = Application.find(params[:id])
      flash[:notice] = "Application updated" if @application.update_attributes(params[:application])
      respond_with @application
    end

    def destroy
      @application = Application.find(params[:id])
      flash[:notice] = "Application deleted" if @application.destroy
      redirect_to applications_url
    end
  end
end
