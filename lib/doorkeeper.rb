require "doorkeeper/version"
require "doorkeeper/engine"
require "doorkeeper/config"
require "doorkeeper/doorkeeper_for"

module Doorkeeper
  autoload :Validations, "doorkeeper/validations"

  module OAuth
    autoload :Scopes,                     "doorkeeper/oauth/scopes"
    autoload :Error,                      "doorkeeper/oauth/error"
    autoload :ErrorResponse,              "doorkeeper/oauth/error_response"
    autoload :AuthorizationRequest,       "doorkeeper/oauth/authorization_request"
    autoload :AccessTokenRequest,         "doorkeeper/oauth/access_token_request"
    autoload :PasswordAccessTokenRequest, "doorkeeper/oauth/password_access_token_request"
    autoload :Authorization,              "doorkeeper/oauth/authorization"
    autoload :Client,                     "doorkeeper/oauth/client"

    module Helpers
      autoload :ScopeChecker, "doorkeeper/oauth/helpers/scope_checker"
      autoload :URIChecker,   "doorkeeper/oauth/helpers/uri_checker"
      autoload :UniqueToken,  "doorkeeper/oauth/helpers/unique_token"
    end
  end

  module Models
    autoload :Expirable, "doorkeeper/models/expirable"
    autoload :Revocable, "doorkeeper/models/revocable"
    autoload :Scopes,    "doorkeeper/models/scopes"
  end
end
