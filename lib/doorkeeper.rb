require "doorkeeper/engine"

module Doorkeeper
  module OAuth
    class MismatchRedirectURI < StandardError; end

    autoload :RandomString,         "doorkeeper/oauth/random_string"
    autoload :AuthorizationRequest, "doorkeeper/oauth/authorization_request"
  end

  def self.setup
    yield self
  end

  mattr_accessor :resource_owner_authenticator
  @@resource_owner_authenticator = nil
end
