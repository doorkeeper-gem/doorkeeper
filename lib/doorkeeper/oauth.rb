module Doorkeeper
  module OAuth
    class MismatchRedirectURI < StandardError; end

    autoload :AuthorizationRequest, "doorkeeper/oauth/authorization_request"
  end
end
