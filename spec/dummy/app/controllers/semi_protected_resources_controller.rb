class SemiProtectedResourcesController < ApplicationController
  doorkeeper_for :only => [:index]

  def index
    render :text => "protected index"
  end

  def show
    render :text => "protected show"
  end
end
