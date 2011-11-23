module Doorkeeper
  class ApplicationsController < ApplicationController
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
  end
end
