Doorkeeper.configure do
  # This block will be called to check whether the
  # resource owner is authenticated or not
  resource_owner_authenticator do
    # put your resource owner authentication logic here
    # e.g. User.find_by_id(session[:user_id])
  end
end
