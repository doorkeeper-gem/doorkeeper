# frozen_string_literal: true

class FullProtectedResourcesController < ApplicationController
  before_action -> { doorkeeper_authorize! :write, :admin }, only: :show
  before_action :doorkeeper_authorize!, only: %i[index create]

  def index
    render plain: "index"
  end

  # Protected and reachable with a form-encoded body, so a request can present
  # a token through RFC 6750 §2.2 and §2.3 at the same time.
  def create
    render plain: "create"
  end

  def show
    render plain: "show"
  end
end
