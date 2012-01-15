require "doorkeeper/engine"
require "doorkeeper/config"
require "doorkeeper/doorkeeper_for"

module Doorkeeper
  autoload :Validations, "doorkeeper/validations"

  module OAuth
    class MismatchRedirectURI < StandardError; end

    autoload :RandomString,         "doorkeeper/oauth/random_string"
    autoload :AuthorizationRequest, "doorkeeper/oauth/authorization_request"
    autoload :AccessTokenRequest,   "doorkeeper/oauth/access_token_request"
    autoload :Authorization,        "doorkeeper/oauth/authorization"

    module Helpers
      autoload :ScopeChecker, "doorkeeper/oauth/helpers/scope_checker"
    end
  end

  def self.setup
    yield self
  end
end
