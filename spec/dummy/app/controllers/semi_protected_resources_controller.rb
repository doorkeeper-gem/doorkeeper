class SemiProtectedResourcesController < ApplicationController
  before_filter :doorkeeper_authorize!, only: :index

  def index
    render text: 'protected index'
  end

  def show
    render text: 'non protected show'
  end
end
