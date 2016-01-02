class FullProtectedResourcesController < ApplicationController
  before_action -> { doorkeeper_authorize! :write, :admin }, only: :show
  before_action :doorkeeper_authorize!, only: :index

  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end
