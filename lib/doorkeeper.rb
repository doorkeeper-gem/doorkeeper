require "doorkeeper/engine"
require "doorkeeper/config"
require "doorkeeper/doorkeeper_for"

module Doorkeeper
  autoload :Validations, "doorkeeper/validations"

  module OAuth
    autoload :RandomString,         "doorkeeper/oauth/random_string"
    autoload :AuthorizationRequest, "doorkeeper/oauth/authorization_request"
    autoload :AccessTokenRequest,   "doorkeeper/oauth/access_token_request"
    autoload :Authorization,        "doorkeeper/oauth/authorization"

    module Helpers
      autoload :ScopeChecker, "doorkeeper/oauth/helpers/scope_checker"
      autoload :URIChecker,   "doorkeeper/oauth/helpers/uri_checker"
    end
  end

  module Models
    autoload :Expirable, "doorkeeper/models/expirable"
    autoload :Revocable, "doorkeeper/models/revocable"
  end
end
