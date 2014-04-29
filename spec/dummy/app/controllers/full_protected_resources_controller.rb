class FullProtectedResourcesController < ApplicationController
  doorkeeper_for :index
  doorkeeper_for :show, scopes: [:admin]

  def index
    render text: 'index'
  end

  def show
    render text: 'show'
  end
end
