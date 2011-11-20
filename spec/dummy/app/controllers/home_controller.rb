class HomeController < ApplicationController
  def index

  end

  def callback
    render :text => "ok"
  end
end
