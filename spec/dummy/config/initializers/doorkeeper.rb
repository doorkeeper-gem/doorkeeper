Doorkeeper.configure do
  # This block will be called to check whether the
  # resource owner is authenticated or not
  resource_owner_authenticator do |routes|
    # put your resource owner authentication logic here
    User.find_by_id(session[:user_id]) || redirect_to(routes.root_url, :alert => "Needs sign in.")
  end

  # If you want to restrict the access to the web interface for
  # adding oauth authorized applications you need to declare the
  # block below
  # admin_authenticator do
  #   Admin.find_by_id(session[:admin_id]) || redirect_to main_app.new_admin_session_path
  # end
  #
  #
  authorization_scopes do
    scope :public, :default => true, :description => "The public one"
    scope :write, :description => "Updating information"
  end
end
