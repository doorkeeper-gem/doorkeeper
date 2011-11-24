Doorkeeper.configure do
  # This block will be called to check whether the
  # resource owner is authenticated or not
  resource_owner_authenticator do
    raise "Please configure doorkeeper resource_owner_authenticator block located in #{__FILE__}"
    # put your resource owner authentication logic here
    # e.g. User.find_by_id(session[:user_id]) || redirect_to main_app.new_user_seesion_path
  end

  # If you want to restrict the access to the web interface for
  # adding oauth authorized applications you need to declare the
  # block below
  # admin_authenticator do
  #   Admin.find_by_id(session[:admin_id]) || redirect_to main_app.new_admin_session_path
  # end
end
