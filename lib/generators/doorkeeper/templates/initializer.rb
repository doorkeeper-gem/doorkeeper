# frozen_string_literal: true

Doorkeeper.configure do
  # Change the ORM that doorkeeper will use (requires ORM extensions installed).
  # Check the list of supported ORMs here: https://github.com/doorkeeper-gem/doorkeeper#orms
  orm :active_record

  # Enable support for multiple database configurations with read replicas.
  # When enabled, Doorkeeper will wrap database write operations to ensure they
  # use the primary (writable) database when automatic role switching is enabled.
  #
  # For ActiveRecord (Rails 6.1+), this uses `ActiveRecord::Base.connected_to(role: :writing)`.
  # Other ORM extensions can implement their own primary database targeting logic.
  #
  # enable_multiple_database_roles
  #
  # This prevents `ActiveRecord::ReadOnlyError` when using read replicas with Rails
  # automatic role switching. Enable this if your application uses multiple databases
  # with automatic role switching for read replicas.
  #
  # See: https://guides.rubyonrails.org/active_record_multiple_databases.html#activating-automatic-role-switching

  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    raise "Please configure doorkeeper resource_owner_authenticator block located in #{__FILE__}"
    # Put your resource owner authentication logic here.
    # Example implementation:
    #   User.find_by(id: session[:user_id]) || redirect_to(new_user_session_url)
  end

  # If you didn't skip applications controller from Doorkeeper routes in your application routes.rb
  # file then you need to declare this block in order to restrict access to the web interface for
  # adding oauth authorized applications. In other case it will return 403 Forbidden response
  # every time somebody will try to access the admin web interface.
  #
  # admin_authenticator do
  #   # Put your admin authentication logic here.
  #   # Example implementation:
  #
  #   if current_user
  #     head :forbidden unless current_user.admin?
  #   else
  #     redirect_to sign_in_url
  #   end
  # end

  # You can use your own model classes if you need to extend (or even override) default
  # Doorkeeper models such as `Application`, `AccessToken` and `AccessGrant.
  #
  # By default Doorkeeper ActiveRecord ORM uses its own classes:
  #
  # access_token_class "Doorkeeper::AccessToken"
  # access_grant_class "Doorkeeper::AccessGrant"
  # application_class "Doorkeeper::Application"
  #
  # Don't forget to include Doorkeeper ORM mixins into your custom models:
  #
  #   *  ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken - for access token
  #   *  ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessGrant - for access grant
  #   *  ::Doorkeeper::Orm::ActiveRecord::Mixins::Application - for application (OAuth2 clients)
  #
  # For example:
  #
  # access_token_class "MyAccessToken"
  #
  # class MyAccessToken < ApplicationRecord
  #   include ::Doorkeeper::Orm::ActiveRecord::Mixins::AccessToken
  #
  #   self.table_name = "hey_i_wanna_my_name"
  #
  #   def destroy_me!
  #     destroy
  #   end
  # end

  # Enables polymorphic Resource Owner association for Access Tokens and Access Grants.
  # By default this option is disabled.
  #
  # Make sure you properly setup you database and have all the required columns (run
  # `bundle exec rails generate doorkeeper:enable_polymorphic_resource_owner` and execute Rails
  # migrations).
  #
  # If this option enabled, Doorkeeper will store not only Resource Owner primary key
  # value, but also it's type (class name). See "Polymorphic Associations" section of
  # Rails guides: https://guides.rubyonrails.org/association_basics.html#polymorphic-associations
  #
  # [NOTE] If you apply this option on already existing project don't forget to manually
  # update `resource_owner_type` column in the database and fix migration template as it will
  # set NOT NULL constraint for Access Grants table.
  #
  # use_polymorphic_resource_owner

  # If you are planning to use Doorkeeper in Rails 5 API-only application, then you might
  # want to use API mode that will skip all the views management and change the way how
  # Doorkeeper responds to a requests.
  #
  # api_only

  # Enforce token request content type to application/x-www-form-urlencoded.
  # It is not enabled by default to not break prior versions of the gem.
  #
  # enforce_content_type

  # Authorization Code expiration time (default: 10 minutes).
  #
  # authorization_code_expires_in 10.minutes

  # Access token expiration time (default: 2 hours).
  # If you set this to `nil` Doorkeeper will not expire the token and omit expires_in in response.
  # It is RECOMMENDED to set expiration time explicitly.
  # Prefer access_token_expires_in 100.years or similar,
  # which would be functionally equivalent and avoid the risk of unexpected behavior by callers.
  #
  # access_token_expires_in 2.hours

  # Assign custom TTL for access tokens. Will be used instead of access_token_expires_in
  # option if defined. In case the block returns `nil` value Doorkeeper fallbacks to
  # +access_token_expires_in+ configuration option value. If you really need to issue a
  # non-expiring access token (which is not recommended) then you need to return
  # Float::INFINITY from this block.
  #
  # `context` has the following properties available:
  #
  #   * `client` - the OAuth client application (see Doorkeeper::OAuth::Client)
  #   * `grant_type` - the grant type of the request (see Doorkeeper::OAuth)
  #   * `scopes` - the requested scopes (see Doorkeeper::OAuth::Scopes)
  #   * `resource_owner` - authorized resource owner instance (if present)
  #
  # custom_access_token_expires_in do |context|
  #   context.client.additional_settings.implicit_oauth_expiration
  # end

  # Use a custom class for generating the access token.
  # See https://doorkeeper.gitbook.io/guides/configuration/other-configurations#custom-access-token-generator
  #
  # access_token_generator '::Doorkeeper::JWT'

  # The controller +Doorkeeper::ApplicationController+ inherits from.
  # Defaults to +ActionController::Base+ unless +api_only+ is set, which changes the default to
  # +ActionController::API+. The return value of this option must be a stringified class name.
  # See https://doorkeeper.gitbook.io/guides/configuration/other-configurations#custom-controllers
  #
  # base_controller 'ApplicationController'

  # Reuse access token for the same resource owner within an application (disabled by default).
  #
  # This option protects your application from creating new tokens before old **valid** one becomes
  # expired so your database doesn't bloat. Keep in mind that when this option is enabled Doorkeeper
  # doesn't update existing token expiration time, it will create a new token instead if no active matching
  # token found for the application, resources owner and/or set of scopes.
  # Rationale: https://github.com/doorkeeper-gem/doorkeeper/issues/383
  #
  # Matching considers only the application, resource owner, scopes, custom access token
  # attributes (see +custom_access_token_attributes+) and whether a refresh token is
  # expected — not the authorization request that produced the token. Separate authorization
  # grants for the same combination share a single access token, so concurrent sessions of
  # the same client become interdependent (e.g. refreshing the token in one session revokes
  # it for the others). If you need independent tokens per session or device, keep this
  # option disabled or differentiate the sessions with +custom_access_token_attributes+.
  # See https://github.com/doorkeeper-gem/doorkeeper/issues/1693
  #
  # You can not enable this option together with +hash_token_secrets+.
  #
  # reuse_access_token

  # In case you enabled `reuse_access_token` option Doorkeeper will try to find matching
  # token using `matching_token_for` Access Token API that searches for valid records
  # in batches in order not to pollute the memory with all the database records. By default
  # Doorkeeper uses batch size of 10 000 records. You can increase or decrease this value
  # depending on your needs and server capabilities.
  #
  # token_lookup_batch_size 10_000

  # Set a limit for token_reuse if using reuse_access_token option
  #
  # This option limits token_reusability to some extent.
  # If not set then access_token will be reused unless it expires.
  # Rationale: https://github.com/doorkeeper-gem/doorkeeper/issues/1189
  #
  # This option should be a percentage(i.e. (0,100])
  #
  # token_reuse_limit 100

  # Only allow one valid access token obtained via client credentials
  # per client. If a new access token is obtained before the old one
  # expired, the old one gets revoked (disabled by default)
  #
  # When enabling this option, make sure that you do not expect multiple processes
  # using the same credentials at the same time (e.g. web servers spanning
  # multiple machines and/or processes).
  #
  # revoke_previous_client_credentials_token

  # Only allow one valid access token obtained via authorization code
  # per client. If a new access token is obtained before the old one
  # expired, the old one gets revoked (disabled by default)
  #
  # revoke_previous_authorization_code_token

  # Require all clients (including confidential ones) to use PKCE when using an
  # authorization code to obtain an access_token (disabled by default)
  #
  # force_pkce

  # Validate the authorization request's client_id and redirect_uri before
  # authenticating the resource owner, so users are not sent through login for
  # a request that can only fail (RFC 6749 Section 4.1.2.1 asks for the
  # resource owner to be informed of an invalid client_id, Section 3.1.2.4 of
  # an invalid redirect URI). Disabled by default: enabling it changes when
  # your `resource_owner_authenticator` block runs, and lets an unauthenticated
  # party learn whether a client_id is registered (client identifiers are not
  # confidential per RFC 6749 Section 2.2). To refuse clients on your own terms
  # as well, override Doorkeeper::AuthorizationsController#validate_client.
  # With use_client_id_metadata_documents this also moves the document fetch,
  # and the application row it materializes, in front of the login: see that
  # option's notes on rate limiting.
  #
  # validate_client_before_resource_owner_authentication

  # Hash access and refresh tokens before persisting them.
  # This will disable the possibility to use +reuse_access_token+
  # since plain values can no longer be retrieved.
  #
  # Note: If you are already a user of doorkeeper and have existing tokens
  # in your installation, they will be invalid without adding 'fallback: :plain'.
  #
  # hash_token_secrets
  # By default, token secrets will be hashed using the
  # +Doorkeeper::Hashing::SHA256+ strategy.
  #
  # If you wish to use another hashing implementation, you can override
  # this strategy as follows:
  #
  # hash_token_secrets using: '::Doorkeeper::Hashing::MyCustomHashImpl'
  #
  # Keep in mind that changing the hashing function will invalidate all existing
  # secrets, if there are any.

  # Hash application secrets before persisting them.
  #
  # hash_application_secrets
  #
  # By default, applications will be hashed
  # with the +Doorkeeper::SecretStoring::SHA256+ strategy.
  #
  # If you wish to use bcrypt for application secret hashing, uncomment
  # this line instead:
  #
  # hash_application_secrets using: '::Doorkeeper::SecretStoring::BCrypt'

  # When the above option is enabled, and a hashed token or secret is not found,
  # you can allow to fall back to another strategy. For users upgrading
  # doorkeeper and wishing to enable hashing, you will probably want to enable
  # the fallback to plain tokens.
  #
  # This will ensure that old access tokens and secrets
  # will remain valid even if the hashing above is enabled.
  #
  # This can be done by adding 'fallback: plain', e.g. :
  #
  # hash_application_secrets using: '::Doorkeeper::SecretStoring::BCrypt', fallback: :plain

  # Issue access tokens with refresh token (disabled by default), you may also
  # pass a block which accepts `context` to customize when to give a refresh
  # token or not. Similar to +custom_access_token_expires_in+, `context` has
  # the following properties:
  #
  # `client` - the OAuth client application (see Doorkeeper::OAuth::Client)
  # `grant_type` - the grant type of the request (see Doorkeeper::OAuth)
  # `scopes` - the requested scopes (see Doorkeeper::OAuth::Scopes)
  #
  # use_refresh_token

  # Provide support for an owner to be assigned to each registered application (disabled by default)
  # Optional parameter confirmation: true (default: false) if you want to enforce ownership of
  # a registered application
  # NOTE: you must also run the rails g doorkeeper:application_owner generator
  # to provide the necessary support
  #
  # enable_application_owner confirmation: false

  # Define access token scopes for your provider
  # For more information go to
  # https://doorkeeper.gitbook.io/guides/ruby-on-rails/scopes
  #
  # default_scopes  :public
  # optional_scopes :write, :update

  # Allows to restrict only certain scopes for grant_type.
  # By default, all the scopes will be available for all the grant types.
  #
  # Keys to this hash should be the name of grant_type and
  # values should be the array of scopes for that grant type.
  # Note: scopes should be from configured_scopes (i.e. default or optional)
  #
  # scopes_by_grant_type password: [:write], client_credentials: [:update]

  # Forbids creating/updating applications with arbitrary scopes that are
  # not in configuration, i.e. +default_scopes+ or +optional_scopes+.
  # (disabled by default)
  #
  # enforce_configured_scopes

  # Configure the OAuth client authentication methods (RFC 6749 §2.3) Doorkeeper
  # will accept and the order in which they are tried. By default it accepts
  # HTTP Basic auth (`client_secret_basic`), credentials in the request body
  # (`client_secret_post`), and public clients with no secret (`none`).
  # Check out https://github.com/doorkeeper-gem/doorkeeper/wiki/Changing-how-clients-are-authenticated
  # for more information on customization
  #
  # client_authentication %i[client_secret_basic client_secret_post none]
  #
  # The legacy `client_credentials` option is deprecated; `:from_basic` and
  # `:from_params` are automatically mapped to `:client_secret_basic` and
  # `:client_secret_post`.
  #
  # A `private_key_jwt` method (RFC 7523 / OIDC Core §9) is also registered
  # but not enabled by default — add it to the list above to accept it. It
  # requires the `jwt` gem (>= 2.7) in your bundle, and verifies assertions
  # against the client's published public keys: the `jwks` / `jwks_uri` of a
  # Client ID Metadata Document client, or `jwks` / `jwks_uri` attributes you
  # define on your Application model for registered clients (Doorkeeper does
  # not add these columns itself). Assertions must carry iss = sub =
  # client_id, an aud of your `issuer` (or the token endpoint URL), a bounded
  # exp (at most 1 hour ahead), a kid header, and a single-use jti of at most
  # 255 characters. exp, nbf and iat must be JSON numbers where present, and
  # nbf is always honoured.
  #
  # jti replay is tracked in process-local memory by default (bounded at
  # 10 000 entries per pool - document clients are accounted apart from
  # registered ones, so neither can crowd the other out - each held until the
  # assertion's own exp, so at most 1 hour plus any global
  # JWT.configuration.decode.leeway you have set), so an assertion replayed to
  # a different server process is not caught. To share the tracking across
  # processes, supply your own store (e.g. backed by Redis):
  #
  # private_key_jwt_replay_guard MyRedisReplayGuard.new
  #
  # It is handed keys shaped "<length>:<client_id>:<jti>", marked with a
  # leading `url:` for a Client ID Metadata Document client. The mark says
  # which pool the built-in guard accounts the entry in, not which assertion
  # it is: a client_id can change provenance while an assertion is still
  # alive, and a jti is single-use per client either way, so decide single use
  # on the key with any leading `url:` taken off.
  #
  # JWK Sets fetched from a `jwks_uri` are cached in process-local memory
  # for 60 seconds; to change the TTL or share the cache across processes:
  #
  # private_key_jwt_jwks_cache Doorkeeper::DocumentCache.new(ttl: 300)
  #
  # This cache serves registered applications only. Keys named by a Client
  # ID Metadata Document are kept on a separate built-in cache, so the
  # unauthenticated traffic that drives those fetches cannot evict entries
  # registered clients depend on.
  #
  # The accepted audiences are built from your `issuer` or from Rails'
  # `default_url_options`; set at least one of them, otherwise Doorkeeper has
  # nothing but the request's Host header to identify itself with and the
  # audience check cannot tell your server apart from another one.
  #
  # A registered client's `jwks_uri` is fetched with the same hardened HTTP
  # client as a metadata document, so a jwks_uri on a private network or on
  # localhost is refused even though you configured it yourself; inline `jwks`
  # has no such restriction.
  #
  # client_authentication %i[client_secret_basic client_secret_post none private_key_jwt]

  # Change the way access token is authenticated from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:access_token` or `:bearer_token` params from the `params` object.
  # Check out https://github.com/doorkeeper-gem/doorkeeper/wiki/Changing-how-clients-are-authenticated
  # for more information on customization
  #
  # access_token_methods :from_bearer_authorization, :from_access_token_param, :from_bearer_param

  # Forces the usage of the HTTPS protocol in non-native redirect uris (enabled
  # by default in non-development environments). OAuth2 delegates security in
  # communication to the HTTPS protocol so it is wise to keep this enabled.
  #
  # Callable objects such as proc, lambda, block or any object that responds to
  # #call can be used in order to allow conditional checks (to allow non-SSL
  # redirects to localhost for example).
  #
  # force_ssl_in_redirect_uri !Rails.env.development?
  #
  # force_ssl_in_redirect_uri { |uri| uri.host != 'localhost' }

  # Specify what redirect URI's you want to block during Application creation.
  # Any redirect URI is allowed by default.
  #
  # You can use this option in order to forbid URI's with 'javascript' scheme
  # for example.
  #
  # forbid_redirect_uri { |uri| uri.scheme.to_s.downcase == 'javascript' }

  # Allows to set blank redirect URIs for Applications in case Doorkeeper configured
  # to use URI-less OAuth grant flows like Client Credentials or Resource Owner
  # Password Credentials. The option is on by default and checks configured grant
  # types, but you **need** to manually drop `NOT NULL` constraint from `redirect_uri`
  # column for `oauth_applications` database table.
  #
  # You almost certainly do not want to change this. There are very, very few cases
  # where you want to change this configuration value.
  #
  # You can completely disable this feature with:
  #
  # allow_blank_redirect_uri false
  #
  # Rows materialized from a Client ID Metadata Document are exempt from this
  # check whatever it is set to (see use_client_id_metadata_documents below):
  # a document need only publish redirect URIs for the grants that redirect,
  # and an empty registration never matches at authorization time.
  #
  # Or you can define your custom check:
  #
  # allow_blank_redirect_uri do |grant_flows, client|
  #   client.superapp?
  # end

  # Specify how authorization errors should be handled.
  # By default, doorkeeper renders json errors when access token
  # is invalid, expired, revoked or has invalid scopes.
  #
  # If you want to render error response yourself (i.e. rescue exceptions),
  # set +handle_auth_errors+ to `:raise` and rescue Doorkeeper::Errors::InvalidToken
  # or following specific errors:
  #
  #   Doorkeeper::Errors::TokenForbidden, Doorkeeper::Errors::TokenExpired,
  #   Doorkeeper::Errors::TokenRevoked, Doorkeeper::Errors::TokenUnknown
  #
  # handle_auth_errors :raise
  #
  # If you want to redirect back to the client application in accordance with
  # https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.2.1, you can set
  # +handle_auth_errors+ to :redirect
  #
  # handle_auth_errors :redirect

  # Customize token introspection response.
  # Allows to add your own fields to default one that are required by the OAuth spec
  # for the introspection response. It could be `sub`, `aud` and so on.
  # This configuration option can be a proc, lambda or any Ruby object responds
  # to `.call` method and result of it's invocation must be a Hash.
  #
  # custom_introspection_response do |token, context|
  #   {
  #     "sub": "Z5O3upPC88QrAjx00dis",
  #     "aud": "https://protected.example.net/resource",
  #     "username": User.find(token.resource_owner_id).username
  #   }
  # end
  #
  # or
  #
  # custom_introspection_response CustomIntrospectionResponder

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
  # The Refresh Token Grant Flow ("refresh_token") doesn't need to be listed
  # here: it is enabled automatically when +use_refresh_token+ is configured.
  #
  # implicit and password grant flows have risks that you should understand
  # before enabling:
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.2
  #   https://datatracker.ietf.org/doc/html/rfc6819#section-4.4.3
  #
  # grant_flows %w[authorization_code client_credentials]

  # Allows to customize OAuth grant flows that +each+ application support.
  # You can configure a custom block (or use a class respond to `#call`) that must
  # return `true` in case Application instance supports requested OAuth grant flow
  # during the authorization request to the server. This configuration +doesn't+
  # set flows per application, it only allows to check if application supports
  # specific grant flow.
  #
  # For example you can add an additional database column to `oauth_applications` table,
  # say `t.array :grant_flows, default: []`, and store allowed grant flows that can
  # be used with this application there. Then when authorization requested Doorkeeper
  # will call this block to check if specific Application (passed with client_id and/or
  # client_secret) is allowed to perform the request for the specific grant type
  # (authorization, password, client_credentials, etc).
  #
  # Example of the block:
  #
  #   ->(flow, client) { client.grant_flows.include?(flow) }
  #
  # In case this option invocation result is `false`, Doorkeeper server returns
  # :unauthorized_client error and stops the request.
  #
  # @param allow_grant_flow_for_client [Proc] Block or any object respond to #call
  # @return [Boolean] `true` if allow or `false` if forbid the request
  #
  # allow_grant_flow_for_client do |grant_flow, client|
  #   # `grant_flows` is an Array column with grant
  #   # flows that application supports
  #
  #   client.grant_flows.include?(grant_flow)
  # end

  # If you need arbitrary Resource Owner-Client authorization you can enable this option
  # and implement the check your need. Config option must respond to #call and return
  # true in case resource owner authorized for the specific application or false in other
  # cases.
  #
  # By default all Resource Owners are authorized to any Client (application).
  #
  # authorize_resource_owner_for_client do |client, resource_owner|
  #   resource_owner.admin? || client.owners_allowlist.include?(resource_owner)
  # end

  # Allows additional data fields to be sent while granting access to an application,
  # and for this additional data to be included in subsequently generated access tokens.
  # The 'authorizations/new' page will need to be overridden to include this additional data
  # in the request params when granting access. The access grant and access token models
  # will both need to respond to these additional data fields, and have a database column
  # to store them in.
  #
  # Example:
  # You have a multi-tenanted platform and want to be able to grant access to a specific
  # tenant, rather than all the tenants a user has access to. You can use this config
  # option to specify that a ':tenant_id' will be passed when authorizing. This tenant_id
  # will be included in the access tokens. When a request is made with one of these access
  # tokens, you can check that the requested data belongs to the specified tenant.
  #
  # Default value is an empty Array: []
  # custom_access_token_attributes [:tenant_id]

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

  # Hook into Authorization flow in order to implement Single Sign Out
  # or add any other functionality. Inside the block you have an access
  # to `controller` (authorizations controller instance) and `context`
  # (Doorkeeper::OAuth::Hooks::Context instance) which provides pre auth
  # or auth objects with issued token based on hook type (before or after).
  #
  # before_successful_authorization do |controller, context|
  #   Rails.logger.info(controller.request.params.inspect)
  #
  #   Rails.logger.info(context.pre_auth.inspect)
  # end
  #
  # after_successful_authorization do |controller, context|
  #   controller.session[:logout_urls] <<
  #     Doorkeeper::Application
  #       .find_by(controller.request.params.slice(:redirect_uri))
  #       .logout_uri
  #
  #   Rails.logger.info(context.auth.inspect)
  #   Rails.logger.info(context.issued_token)
  # end

  # Under some circumstances you might want to have applications auto-approved,
  # so that the user skips the authorization step.
  # For example if dealing with a trusted application.
  #
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

  # WWW-Authenticate Realm (default: "Doorkeeper").
  #
  # realm "Doorkeeper"

  # OAuth 2.0 Authorization Server Metadata (RFC 8414).
  #
  # Doorkeeper exposes an authorization server metadata document at
  # `/.well-known/oauth-authorization-server`, built from the configuration
  # above. The two options below let you customize that document.
  #
  # `issuer` is the authorization server's issuer identifier. When left as nil
  # (the default) the request base URL is used for the metadata `issuer` field
  # only. Note the asymmetry: RFC 9207 below is gated on an explicitly
  # configured issuer, so leaving it nil still advertises a metadata `issuer`
  # (the base URL) while `authorization_response_iss_parameter_supported` stays
  # false and no `iss` parameter is emitted.
  #
  # Configuring an issuer also enables RFC 9207 (Authorization Server Issuer
  # Identification): the `iss` parameter is added to the authorization
  # responses redirected back to the client - both successful responses and
  # error responses such as access_denied - and advertised via the
  # `authorization_response_iss_parameter_supported` metadata field. Clients
  # that parse the authorization redirect will start seeing this parameter.
  # Per RFC 8414 and RFC 9207 the value should be an https URL with no query or
  # fragment; a non-compliant value logs a warning at boot but is still used.
  # Prefer a host-only issuer: Doorkeeper serves its metadata only at the root
  # /.well-known/oauth-authorization-server, so a path-bearing issuer (e.g.
  # https://auth.example.com/tenant) is not discoverable by RFC 8414 clients and
  # also logs a warning.
  #
  # issuer "https://auth.example.com"
  #
  # `custom_metadata` is a Hash that is merged into the metadata response. Use
  # it to advertise additional or non-default metadata fields, for example a
  # `userinfo_endpoint` (which Doorkeeper itself leaves null) when pairing with
  # an OpenID Connect extension.
  #
  # The merge happens last, so it can also override computed fields - including
  # `authorization_response_iss_parameter_supported`, which Doorkeeper derives
  # from whether `issuer` is set. Overriding a computed field is allowed but is
  # your responsibility to keep consistent with the server's actual behaviour
  # (e.g. don't advertise iss support as true if no `issuer` is configured).
  #
  # custom_metadata(
  #   userinfo_endpoint: "https://auth.example.com/oauth/userinfo",
  # )

  # Resource Indicators for OAuth 2.0 (RFC 8707)
  #
  # When configured with a callable, enables RFC 8707 support. The callable
  # receives an array of resource indicator URIs and the OAuth client, and must
  # return true if the resources are acceptable, or false to reject with
  # `invalid_target`.
  #
  # Clients may then include one or more `resource` parameters in authorization
  # and token requests to signal which protected resource(s) they intend to
  # access. The authorization server will:
  #   - Validate resource URIs (must be absolute, no fragment)
  #   - Store resource indicators on grants and tokens
  #   - Enforce subset restrictions on token/refresh requests
  #   - Include `aud` in token introspection responses
  #
  # NOTE: RFC 8707 specifies repeated query parameters (?resource=…&resource=…)
  # for multiple values, but Rack collapses repeated keys to the last value.
  # Clients must use the Rails bracket syntax (resource[]=…&resource[]=…) to
  # send multiple resource indicators. A single resource=… works as-is.
  #
  # To use this feature, first run `rails generate doorkeeper:resource_indicators`
  # to add the required `resource` column to the access grants and tokens tables.
  #
  # resource_indicator_validator ->(resource_indicators, client) {
  #   allowed = %w[https://api.example.com/ https://calendar.example.com/]
  #   resource_indicators.all? { |r| allowed.include?(r) }
  # }

  # Client ID Metadata Documents (draft-ietf-oauth-client-id-metadata-document).
  #
  # When enabled, clients may identify themselves with an https:// client_id
  # pointing at a metadata document (JSON) that Doorkeeper fetches and
  # validates instead of requiring pre-registration. Only URL-shaped
  # client_ids take this path; opaque client_ids keep resolving against
  # registered applications, and Doorkeeper-generated uids never start with
  # "https://".
  #
  # The feature requires a datetime column on your applications table that
  # Doorkeeper's own migrations do not add:
  #
  #   add_column :oauth_applications, :client_id_metadata_materialized_at, :datetime
  #
  # With the Mongoid extension (doorkeeper-mongodb) there is no migration to
  # run, but the field has to be declared, since its application model lists
  # its fields explicitly. That model is defined from Doorkeeper's own
  # to_prepare hook, so it does not exist while this file is being loaded;
  # declare the field from your application's to_prepare instead, which runs
  # after Doorkeeper's:
  #
  #   # config/application.rb
  #   config.to_prepare do
  #     Doorkeeper::Application.field :client_id_metadata_materialized_at, type: Time
  #   end
  #
  # With the Sequel extension (doorkeeper-sequel) the column is added by a
  # Sequel migration instead:
  #
  #   alter_table(:oauth_applications) do
  #     add_column :client_id_metadata_materialized_at, DateTime
  #   end
  #
  # The column records which rows were materialized from a fetched document,
  # and is what tells an application whose uid was manually set to an
  # https:// URL apart from a metadata document client - the draft's
  # Section 7.1 warns that the prefix alone cannot make that distinction,
  # and Section 7.2 permits pre-registering such Client Identifier URLs.
  # Such a registered row keeps working as the registered application it is,
  # exactly as it does with this option off: its URL is never fetched, and
  # the row is never refreshed from what the URL serves (whoever controls
  # the URL would otherwise inherit the grants and tokens attached to it).
  # One thing such a client cannot do, with this option on or off, is
  # authenticate with client_secret_basic: Doorkeeper splits the Basic
  # credential at the first ":" and does not URL-decode it (see
  # ClientAuthentication::ClientSecretBasic), and every URL carries one.
  # It authenticates with client_secret_post, or with an assertion.
  # The flip side is that a registered application holding a URL as its uid
  # pre-empts the document client at that URL, so if your host application
  # lets users choose their applications' uids, make sure they cannot choose
  # https:// URLs. Without the column the feature refuses every metadata
  # document client.
  #
  # Notes and current limitations:
  # - Metadata is fetched over HTTPS only, redirects are not followed, and
  #   hosts resolving to RFC 6890 special-use addresses (loopback, private
  #   ranges, link-local, ...) are refused, so local development targets
  #   cannot be fetched by design.
  # - A document body larger than 5 KB is refused, and the whole exchange is
  #   capped at 13 KB at the socket (an 8 KB allowance for the status line and
  #   headers on top of the body), so a host streaming headers cannot buffer
  #   its way around the body limit - and so is a document that is not valid
  #   UTF-8. The HTTP exchange is
  #   bounded in time as well (name resolution is bounded by your resolver's
  #   own timeouts), so a slow or oversized document cannot tie up a request.
  # - Each successfully validated client is materialized as an application
  #   row (uid = the client_id URL) so grants and tokens can reference it;
  #   rows are refreshed from the document on every resolution. Consider the
  #   growth of this table before enabling the feature on a public server,
  #   and note what triggers a fetch: an authorization request, which never
  #   authenticates the client, does so as soon as its resource owner is
  #   signed in - and before any sign-in at all once
  #   validate_client_before_resource_owner_authentication is on, which
  #   moves the fetch and the row in front of the login screen. So does a
  #   URL client_id at any endpoint that authenticates the client, where
  #   there is no resource owner in the first place: token, revocation and
  #   introspection all materialize the row for a public ("none") document
  #   client. Each such
  #   request holds the Rails thread serving it for as long as the fetch
  #   takes - up to 10 seconds for the HTTP exchange, plus whatever your
  #   resolver spends on a name that does not resolve. That last part is
  #   outside the 10 seconds and is the larger number of the two where a
  #   name is served by hosts that answer nothing at all: Resolv tries every
  #   candidate its search list produces, for both record types, with its
  #   own escalating timeouts. The timeouts are not configurable here, so a
  #   caller naming many slow hosts can occupy your worker pool. Rate limiting, of all of these endpoints, is left to the
  #   host application, and this feature needs it. A document
  #   whose row fails the model's validation is refused as invalid_client,
  #   and the reason is logged.
  # - Disabling the option later also disables every client it materialized:
  #   a row stamped with client_id_metadata_materialized_at is refused as a
  #   client while the option is off, since nothing refreshes it any more
  #   and no one ever registered it. Registered applications, URL-shaped uid
  #   or not, are untouched. To keep such a client for good, clear its stamp
  #   and own it as a registered application from then on. Access tokens
  #   already issued to such rows stay valid until they expire, since
  #   resource requests never consult the application; revoke them if access
  #   is to stop at once.
  # - The consent screen names the one part of a document client's identity
  #   it demonstrably controls - its URL's host (draft Section 8.5) - via
  #   the engine's authorizations/new view and the client_id_host_html
  #   translation. If you copied Doorkeeper's views (rails g
  #   doorkeeper:views) or overrode that screen or its translations, port
  #   that line to your copy before enabling this: your users would
  #   otherwise see only whatever unverified client_name the document
  #   declares for itself. Doorkeeper ships that translation in English
  #   only, so on a server serving other locales it needs a translation of
  #   its own until doorkeeper-i18n carries the key. In api_only mode the
  #   consent JSON carries no such host; derive it from the application with
  #   Doorkeeper::ClientIdMetadata.display_host when rendering your own. The
  #   same host is shown beside the client's name in the engine's
  #   authorized_applications list, where the user reads it again later.
  # - A document client is asked for consent on every authorization: an
  #   earlier authorization is not reused to skip the screen the way it is
  #   for a registered confidential client, since the document's redirect
  #   URIs and keys may have changed since (draft Sections 8.3 / 8.4).
  #   `skip_authorization` applies to such clients like any other. The rule
  #   lives in the engine's `matching_token?`, so any consent gate that reads
  #   it composes with it - but an extension deciding consent on its own
  #   does not. With doorkeeper-openid_connect, in particular, a
  #   `prompt=none` request can still be answered from an existing token
  #   until its matching companion change ships; ask for
  #   `Doorkeeper::ClientIdMetadata.consent_required_every_time?(application)`
  #   in your own gates until then.
  # - A document's redirect_uris are validated the way a registered
  #   application's are, `force_ssl_in_redirect_uri` included: a single
  #   http:// entry - an RFC 8252 loopback redirect URI, say - refuses the
  #   whole document. Native-app document clients need that option relaxed
  #   for loopback URIs (see its notes above). A document that publishes no
  #   redirect_uris at all is materialized with none, whatever
  #   allow_blank_redirect_uri is set to: an empty registration matches no
  #   redirect at authorization time, so such a client keeps only the grants
  #   that never redirect.
  # - Documents must not use shared-secret authentication methods, and must
  #   publish public keys only (draft Section 4.1): a jwks carrying private
  #   or symmetric key material is refused along with the document, while
  #   such keys served from a jwks_uri - which is fetched separately, and may
  #   never be - are dropped when the keys are read. Public clients ("none")
  #   should be combined with force_pkce.
  # - Using `private_key_jwt` with document clients requires this server to
  #   identify itself, through the `issuer` option above or Rails'
  #   `default_url_options[:host]`. A document client_id resolves to the same
  #   client, and the same keys, at every server implementing the draft, so
  #   the audience its assertions are checked against (RFC 7523 Section 3)
  #   must not come from the request's Host header - otherwise an assertion
  #   sent to one such server would be replayable at all the others by
  #   whoever received it. Without either setting, those assertions are
  #   refused and a warning is logged at boot. Registered applications
  #   authenticate as they did before this option.
  # - Not compatible with `enable_application_owner confirmation: true`. A
  #   document client is registered by no one, so the application row it is
  #   materialized as has no owner and fails that validation, leaving every
  #   such client refused as invalid_client. A warning is logged at boot when
  #   both options are set.
  # - A document served with a media type that is not JSON is refused (one
  #   declaring no media type at all is tolerated), and a client_id URL,
  #   client_name or scope longer than 255 characters is rejected: those
  #   values go into columns the generated migration declares as strings,
  #   which MySQL sizes at 255 characters. A client_name carrying control
  #   characters or bidirectional overrides is rejected as well, since it is
  #   read by your users on the consent screen, and so is a redirect_uris
  #   entry that is blank or holds more than one URI. A leading byte order
  #   mark is ignored rather than read as malformed JSON, and a property
  #   explicitly set to null counts as one the document did not set.
  # - Rows are refreshed from the document on every resolution, so editing
  #   one through your applications admin UI does not hold: the next
  #   resolution writes the document's values back over it. Delete the row,
  #   or clear its stamp to adopt it as a registered application, instead.
  # - A document may only name scopes this server configures; one naming
  #   anything else is rejected rather than granted it, since an
  #   application's own scopes stand in for the server's when a token is
  #   issued.
  # - Of the client metadata, only client_name, redirect_uris, scope,
  #   token_endpoint_auth_method and jwks/jwks_uri are honoured. In
  #   particular grant_types and response_types are not enforced, so a
  #   document client may use any grant flow you have enabled - review
  #   `grant_flows` before enabling this. The exceptions are the two grants
  #   that hand out a token with no resource owner in front of them:
  #   `client_credentials`, which RFC 6749 Section 4.4 reserves for
  #   confidential clients, and `password` (even where
  #   skip_client_authentication_for_password_grant is on). A document
  #   naming "none" is refused both.
  # - A document naming `private_key_jwt` is *not* refused them: it is a
  #   confidential client in the RFC's sense, and its key is its own. So on
  #   a server that enables this option, that method and the
  #   `client_credentials` grant (which `grant_flows` includes by default),
  #   anyone who can host a JSON document and generate a key pair can obtain
  #   an access token for the client itself, without registering anything.
  #   Such a token is issued the scopes it asks for, and a document that
  #   names no `scope` of its own is held to no allow-list, so that is every
  #   scope this server configures, optional_scopes included. Restrict it
  #   with `scopes_by_grant_type client_credentials: [...]`, or leave the
  #   grant out of `grant_flows`, before enabling this on a public server -
  #   an API guarded by scope alone would otherwise be open to anyone.
  # - A document naming "none" is refused as an introspection caller as well
  #   (RFC 7662 Section 4 has that endpoint authorize its caller "to prevent
  #   token scanning attacks", and hosting a document is not an
  #   authorization): the request is answered invalid_client, and
  #   `allow_token_introspection` is never consulted for it. The attempt
  #   still resolves the document and materializes the row, so the rate
  #   limiting above covers this endpoint too.
  # - A *confidential* document client - one authenticating with
  #   private_key_jwt - introspects like any registered confidential client,
  #   under whatever `allow_token_introspection` you configure. If you want
  #   to narrow that, keep the default policy's same-application rule and add
  #   to it rather than replacing it; a block that only asks whether the
  #   caller is a document client would let any caller introspect any token.
  # - Documents are memoized for 60 seconds. The HTTP cache headers the draft
  #   recommends respecting (Section 5.2) are not honoured yet, and no
  #   development metadata document service (Appendix A) is provided.
  # - Only documents that fetch and validate are memoized - error responses
  #   and invalid documents never are (Section 5.2); one whose application
  #   row is then refused stays memoized for the TTL - and the memo is keyed
  #   by the client_id exactly as it was sent (the draft requires client_ids to be
  #   compared as strings), so case variants of one URL are as many separate
  #   clients: a caller choosing URLs freely can drive one outbound fetch,
  #   and one application row, per request. Rate limit the authorization and
  #   token endpoints accordingly. The uid column decides that comparison
  #   for stored rows, though, and MySQL's default collation is
  #   case-insensitive: there two client_id URLs differing only in case
  #   collide on the unique index, and the second one is refused as
  #   invalid_client for as long as the first row exists. Declare the column
  #   as utf8mb4_bin, or require lowercase URLs, if that matters to you.
  # - A change of client keys does not revoke previously issued tokens
  #   (Section 8.4.1), and logo_uri is never prefetched (Section 8.8).
  #
  # use_client_id_metadata_documents
end
