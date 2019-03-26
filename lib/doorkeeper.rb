# frozen_string_literal: true

require "doorkeeper/version"
require "doorkeeper/engine"
require "doorkeeper/config"

require "doorkeeper/request/strategy"
require "doorkeeper/request/authorization_code"
require "doorkeeper/request/client_credentials"
require "doorkeeper/request/code"
require "doorkeeper/request/password"
require "doorkeeper/request/refresh_token"
require "doorkeeper/request/token"

require "doorkeeper/errors"
require "doorkeeper/server"
require "doorkeeper/request"
require "doorkeeper/validations"

require "doorkeeper/oauth/authorization/code"
require "doorkeeper/oauth/authorization/context"
require "doorkeeper/oauth/authorization/token"
require "doorkeeper/oauth/authorization/uri_builder"
require "doorkeeper/oauth/helpers/scope_checker"
require "doorkeeper/oauth/helpers/uri_checker"
require "doorkeeper/oauth/helpers/unique_token"

require "doorkeeper/oauth"
require "doorkeeper/oauth/scopes"
require "doorkeeper/oauth/error"
require "doorkeeper/oauth/base_response"
require "doorkeeper/oauth/code_response"
require "doorkeeper/oauth/token_response"
require "doorkeeper/oauth/error_response"
require "doorkeeper/oauth/pre_authorization"
require "doorkeeper/oauth/base_request"
require "doorkeeper/oauth/authorization_code_request"
require "doorkeeper/oauth/refresh_token_request"
require "doorkeeper/oauth/password_access_token_request"

require "doorkeeper/oauth/client_credentials/validation"
require "doorkeeper/oauth/client_credentials/creator"
require "doorkeeper/oauth/client_credentials/issuer"
require "doorkeeper/oauth/client_credentials/validation"
require "doorkeeper/oauth/client/credentials"

require "doorkeeper/oauth/client_credentials_request"
require "doorkeeper/oauth/code_request"
require "doorkeeper/oauth/token_request"
require "doorkeeper/oauth/client"
require "doorkeeper/oauth/token"
require "doorkeeper/oauth/token_introspection"
require "doorkeeper/oauth/invalid_token_response"
require "doorkeeper/oauth/forbidden_token_response"

require "doorkeeper/secret_storing/base"
require "doorkeeper/secret_storing/plain"
require "doorkeeper/secret_storing/sha256_hash"
require "doorkeeper/secret_storing/bcrypt"

require "doorkeeper/models/concerns/orderable"
require "doorkeeper/models/concerns/scopes"
require "doorkeeper/models/concerns/expirable"
require "doorkeeper/models/concerns/reusable"
require "doorkeeper/models/concerns/revocable"
require "doorkeeper/models/concerns/accessible"
require "doorkeeper/models/concerns/secret_storable"

require "doorkeeper/models/access_grant_mixin"
require "doorkeeper/models/access_token_mixin"
require "doorkeeper/models/application_mixin"

require "doorkeeper/helpers/controller"

require "doorkeeper/rails/routes"
require "doorkeeper/rails/helpers"

require "doorkeeper/rake"
require "doorkeeper/stale_records_cleaner"

require "doorkeeper/orm/active_record"

module Doorkeeper
  def self.authenticate(request, methods = Doorkeeper.configuration.access_token_methods)
    OAuth::Token.authenticate(request, *methods)
  end
end
