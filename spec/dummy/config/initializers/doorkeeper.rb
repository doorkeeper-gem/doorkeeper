Doorkeeper.configure do
  # This block will be called to check whether the
  # resource owner is authenticated or not
  resource_owner_authenticator do
    # put your resource owner authentication logic here
    User.find_by_id(session[:user_id]) || redirect_to(main_app.root_url, :alert => "Needs sign in.")
  end
end
