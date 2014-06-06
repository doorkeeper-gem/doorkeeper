Doorkeeper.configure do
  # Change the ORM that doorkeeper will use
  # Currently supported options are :active_record, :mongoid2, :mongoid3, :mongo_mapper
  orm DOORKEEPER_ORM

  # This block will be called to check whether the
  # resource owner is authenticated or not
  resource_owner_authenticator do
    # Put your resource owner authentication logic here.
    # e.g. User.find_by_id(session[:user_id]) || redirect_to(new_user_session_url)
    User.where(id: session[:user_id]).first || redirect_to(root_url, alert: 'Needs sign in.')
  end

  # If you want to restrict the access to the web interface for
  # adding oauth authorized applications you need to declare the
  # block below
  # admin_authenticator do
  #   # Put your admin authentication logic here.
  #   Admin.find_by_id(session[:admin_id]) || redirect_to(new_admin_session_url)
  # end

  # Authorization Code expiration time (default 10 minutes).
  # access_token_expires_in 10.minutes

  # Access token expiration time (default 2 hours)
  # If you want to disable expiration, set this to nil.
  # access_token_expires_in 2.hours

  # Issue access tokens with refresh token (disabled by default)
  use_refresh_token

  # Define access token scopes for your provider
  # For more information go to
  # https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes
  default_scopes  :public
  optional_scopes :write, :update

  # Change the way client credentials are retrieved from the request object.
  # By default it retrieves first from `HTTP_AUTHORIZATION` header and
  # fallsback to `:client_id` and `:client_secret` from `params` object
  # Check out the wiki for mor information on customization
  # client_credentials :from_basic, :from_params

  # Change the way access token is authenticated from the request object.
  # By default it retrieves first from `HTTP_AUTHORIZATION` header and
  # fallsback to `:access_token` or `:bearer_token` from `params` object
  # Check out the wiki for mor information on customization
  # access_token_methods :from_bearer_authorization, :from_access_token_param, :from_bearer_param

  # Change the native redirect uri for client apps
  # When clients register with the following redirect uri, they won't be redirected to any server and the authorization code will be displayed within the provider
  # The value can be any string. Use nil to disable this feature. When disabled, clients must provide a valid URL
  # (Similar behaviour: https://developers.google.com/accounts/docs/OAuth2InstalledApp#choosingredirecturi)
  #
  # native_redirect_uri 'urn:ietf:wg:oauth:2.0:oob'

  # WWW-Authenticate Realm (default 'Doorkeeper').
  realm 'Doorkeeper'
end
