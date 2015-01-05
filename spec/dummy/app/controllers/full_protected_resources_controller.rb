class FullProtectedResourcesController < ApplicationController
  before_filter -> { doorkeeper_authorize! :admin }, only: :show
  before_filter :doorkeeper_authorize!, only: :index

  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end
