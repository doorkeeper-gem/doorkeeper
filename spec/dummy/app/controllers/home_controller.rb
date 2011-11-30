class HomeController < ApplicationController
  def index

  end

  def sign_in
    session[:user_id] = User.first || User.create!
    redirect_to '/'
  end

  def callback
    render :text => "ok"
  end
end
