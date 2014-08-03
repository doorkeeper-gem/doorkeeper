class SemiProtectedResourcesController < ApplicationController
  before_filter :doorkeeper_authorize!

  def index
    render text: 'protected index'
  end

  def show
    render text: 'protected show'
  end
end
