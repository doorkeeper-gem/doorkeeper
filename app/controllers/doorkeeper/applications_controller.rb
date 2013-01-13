module Doorkeeper
  class ApplicationsController < Doorkeeper::ApplicationController
    before_filter :authenticate_admin!

    def index
      @applications = Doorkeeper.client.all
    end

    def new
      @application = Doorkeeper.client.new
    end

    def create
      @application  = Doorkeeper.client.new(params[:application])

      if @application.save
        redirect_to oauth_application_url(@application), :notice => t('doorkeeper.flash.applications.create.notice')
      else
        render :new
      end
    end

    def show
      @application = Doorkeeper.client.find(params[:id])
    end

    def edit
      @application = Doorkeeper.client.find(params[:id])
    end

    def update
      @application = Doorkeeper.client.find(params[:id])

      if @application.update_attributes(params[:application])
        redirect_to oauth_application_url(@application), :notice => t('doorkeeper.flash.applications.update.notice')
      else
        render :edit
      end
    end

    def destroy
      @application = Doorkeeper.client.find(params[:id])
      @application.destroy

      redirect_to :oauth_applications, :notice => t('doorkeeper.flash.applications.destroy.notice')
    end
  end
end
