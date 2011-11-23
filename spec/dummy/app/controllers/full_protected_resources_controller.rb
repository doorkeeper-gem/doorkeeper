class FullProtectedResourcesController < ApplicationController
  doorkeeper_for :all

  def index
    render :text => "index"
  end

  def show
    render :text => "show"
  end
end
