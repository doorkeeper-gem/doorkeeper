class SemiProtectedResourcesController < ApplicationController
  before_action :doorkeeper_authorize!, only: :index

  def index
    render text: 'protected index'
  end

  def show
    render text: 'non protected show'
  end
end
