# frozen_string_literal: true

Doorkeeper.configure do
  # Change the ORM that doorkeeper will use.
  orm DOORKEEPER_ORM

  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    # Put your resource owner authentication logic here.
    User.where(id: session[:user_id]).first || redirect_to(root_url, alert: "Needs sign in.")
  end

  # If you didn't skip applications controller from Doorkeeper routes in your application routes.rb
  # file then you need to declare this block in order to restrict access to the web interface for
  # adding oauth authorized applications. In other case it will return 403 Forbidden response
  # every time somebody will try to access the admin web interface.
  #
  # admin_authenticator do
  #   # Put your admin authentication logic here.
  #   # Example implementation:
  #   Admin.find_by_id(session[:admin_id]) || redirect_to(new_admin_session_url)
  # end

  # Authorization Code expiration time (default 10 minutes).
  # authorization_code_expires_in 10.minutes

  # Access token expiration time (default 2 hours).
  # If you want to disable expiration, set this to nil.
  # access_token_expires_in 2.hours

  # Reuse access token for the same resource owner within an application (disabled by default)
  # Rationale: https://github.com/doorkeeper-gem/doorkeeper/issues/383
  # reuse_access_token

  # Issue access tokens with refresh token (disabled by default)
  use_refresh_token

  # Forbids creating/updating applications with arbitrary scopes that are
  # not in configuration, i.e. `default_scopes` or `optional_scopes`.
  # (disabled by default)
  #
  # enforce_configured_scopes

  # Use the url path for the native authorization code flow. Enabling this flag sets the authorization
  # code response route for native redirect uris to oauth/authorize/<code>. The default is oauth/authorize/native?code=<code>.
  # Rationale: https://github.com/doorkeeper-gem/doorkeeper/issues/1143
  # use_url_path_for_native_authorization

  # Provide support for an owner to be assigned to each registered application (disabled by default)
  # Optional parameter confirmation: true (default false) if you want to enforce ownership of
  # a registered application
  # Note: you must also run the rails g doorkeeper:application_owner generator to provide the necessary support
  # enable_application_owner confirmation: false

  # Define access token scopes for your provider
  # For more information go to
  # https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes
  default_scopes  :public
  optional_scopes :write, :update

  # Change the way client credentials are retrieved from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:client_id` and `:client_secret` params from the `params` object.
  # Check out the wiki for more information on customization
  # client_credentials :from_basic, :from_params

  # Change the way access token is authenticated from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:access_token` or `:bearer_token` params from the `params` object.
  # Check out the wiki for more information on customization
  # access_token_methods :from_bearer_authorization, :from_access_token_param, :from_bearer_param

  # Forces the usage of the HTTPS protocol in non-native redirect uris (enabled
  # by default in non-development environments). OAuth2 delegates security in
  # communication to the HTTPS protocol so it is wise to keep this enabled.
  #
  # force_ssl_in_redirect_uri !Rails.env.development?

  # Specify what grant flows are enabled in array of Strings. The valid
  # strings and the flows they enable are:
  #
  # "authorization_code" => Authorization Code Grant Flow
  # "implicit"           => Implicit Grant Flow
  # "password"           => Resource Owner Password Credentials Grant Flow
  # "client_credentials" => Client Credentials Grant Flow
  #
  # If not specified, Doorkeeper enables authorization_code and
  # client_credentials.
  #
  # implicit and password grant flows have risks that you should understand
  # before enabling:
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.2
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.3
  #
  # grant_flows %w[authorization_code client_credentials]

  # Hook into the strategies' request & response life-cycle in case your
  # application needs advanced customization or logging:
  #
  # before_successful_strategy_response do |request|
  #   puts "BEFORE HOOK FIRED! #{request}"
  # end
  #
  # after_successful_strategy_response do |request, response|
  #   puts "AFTER HOOK FIRED! #{request}, #{response}"
  # end

  # Under some circumstances you might want to have applications auto-approved,
  # so that the user skips the authorization step.
  # For example if dealing with a trusted application.
  # skip_authorization do |resource_owner, client|
  #   client.superapp? or resource_owner.admin?
  # end

  # Configure custom constraints for the Token Introspection request.
  # By default this configuration option allows to introspect a token by another
  # token of the same application, OR to introspect the token that belongs to
  # authorized client (from authenticated client) OR when token doesn't
  # belong to any client (public token). Otherwise requester has no access to the
  # introspection and it will return response as stated in the RFC.
  #
  # Block arguments:
  #
  # @param token [Doorkeeper::AccessToken]
  #   token to be introspected
  #
  # @param authorized_client [Doorkeeper::Application]
  #   authorized client (if request is authorized using Basic auth with
  #   Client Credentials for example)
  #
  # @param authorized_token [Doorkeeper::AccessToken]
  #   Bearer token used to authorize the request
  #
  # In case the block returns `nil` or `false` introspection responses with 401 status code
  # when using authorized token to introspect, or you'll get 200 with { "active": false } body
  # when using authorized client to introspect as stated in the
  # RFC 7662 section 2.2. Introspection Response.
  #
  # Using with caution:
  # Keep in mind that these three parameters pass to block can be nil as following case:
  #  `authorized_client` is nil if and only if `authorized_token` is present, and vice versa.
  #  `token` will be nil if and only if `authorized_token` is present.
  # So remember to use `&` or check if it is present before calling method on
  # them to make sure you doesn't get NoMethodError exception.
  #
  # You can define your custom check:
  #
  # allow_token_introspection do |token, authorized_client, authorized_token|
  #   if authorized_token
  #     # customize: require `introspection` scope
  #     authorized_token.application == token&.application ||
  #       authorized_token.scopes.include?("introspection")
  #   elsif token.application
  #     # `protected_resource` is a new database boolean column, for example
  #     authorized_client == token.application || authorized_client.protected_resource?
  #   else
  #     # public token (when token.application is nil, token doesn't belong to any application)
  #     true
  #   end
  # end
  #
  # Or you can completely disable any token introspection:
  #
  # allow_token_introspection false
  #
  # If you need to block the request at all, then configure your routes.rb or web-server
  # like nginx to forbid the request.

  # WWW-Authenticate Realm (default "Doorkeeper").
  realm "Doorkeeper"
end
