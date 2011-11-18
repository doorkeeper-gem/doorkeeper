Doorkeeper.setup do |config|
  # This block will be called to check whether the
  # resource owner is authenticated or not
  config.resource_owner_authenticator = proc do
    # e.g. User.find_by_id(session[:user_id])
  end
end
