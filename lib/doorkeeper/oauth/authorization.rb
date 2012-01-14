module Doorkeeper
  module OAuth
    module Authorization
      autoload :Code,       "doorkeeper/oauth/authorization/code"
      autoload :Token,      "doorkeeper/oauth/authorization/token"
      autoload :URIBuilder, "doorkeeper/oauth/authorization/uri_builder"
    end
  end
end
