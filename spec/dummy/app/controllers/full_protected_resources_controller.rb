class FullProtectedResourcesController < ApplicationController
  before_filter :doorkeeper_authorize_public!, only: :index
  before_filter :doorkeeper_authorize_admin!, only: :show

  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end
