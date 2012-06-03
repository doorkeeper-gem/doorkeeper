module Doorkeeper
  module OAuth
    # TODO: move this to doorkeeper.rb
    module Authorization
      autoload :Code,       "doorkeeper/oauth/authorization/code"
      autoload :Token,      "doorkeeper/oauth/authorization/token"
      autoload :URIBuilder, "doorkeeper/oauth/authorization/uri_builder"
    end
  end
end
