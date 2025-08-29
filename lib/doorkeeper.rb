# frozen_string_literal: true

require "doorkeeper/config"
require "doorkeeper/engine"

# Main Doorkeeper namespace.
#
module Doorkeeper
  autoload :Errors, "doorkeeper/errors"
  autoload :ClientAuthentication, "doorkeeper/client_authentication"
  autoload :GrantFlow, "doorkeeper/grant_flow"
  autoload :OAuth, "doorkeeper/oauth"
  autoload :Rake, "doorkeeper/rake"
  autoload :Request, "doorkeeper/request"
  autoload :Server, "doorkeeper/server"
  autoload :StaleRecordsCleaner, "doorkeeper/stale_records_cleaner"
  autoload :Validations, "doorkeeper/validations"
  autoload :VERSION, "doorkeeper/version"

  autoload :AccessGrantMixin, "doorkeeper/models/access_grant_mixin"
  autoload :AccessTokenMixin, "doorkeeper/models/access_token_mixin"
  autoload :ApplicationMixin, "doorkeeper/models/application_mixin"

  module Helpers
    autoload :Controller, "doorkeeper/helpers/controller"
  end

  module Request
    autoload :Strategy, "doorkeeper/request/strategy"
    autoload :AuthorizationCode, "doorkeeper/request/authorization_code"
    autoload :ClientCredentials, "doorkeeper/request/client_credentials"
    autoload :Code, "doorkeeper/request/code"
    autoload :Password, "doorkeeper/request/password"
    autoload :RefreshToken, "doorkeeper/request/refresh_token"
    autoload :Token, "doorkeeper/request/token"
  end
  module RevocableTokens
    autoload :RevocableAccessToken, "doorkeeper/revocable_tokens/revocable_access_token"
    autoload :RevocableRefreshToken, "doorkeeper/revocable_tokens/revocable_refresh_token"
  end

  module OAuth
    autoload :BaseRequest, "doorkeeper/oauth/base_request"
    autoload :AuthorizationCodeRequest, "doorkeeper/oauth/authorization_code_request"
    autoload :BaseResponse, "doorkeeper/oauth/base_response"
    autoload :CodeResponse, "doorkeeper/oauth/code_response"
    autoload :Client, "doorkeeper/oauth/client"
    autoload :ClientCredentialsRequest, "doorkeeper/oauth/client_credentials_request"
    autoload :CodeRequest, "doorkeeper/oauth/code_request"
    autoload :ErrorResponse, "doorkeeper/oauth/error_response"
    autoload :Error, "doorkeeper/oauth/error"
    autoload :InvalidTokenResponse, "doorkeeper/oauth/invalid_token_response"
    autoload :InvalidRequestResponse, "doorkeeper/oauth/invalid_request_response"
    autoload :ForbiddenTokenResponse, "doorkeeper/oauth/forbidden_token_response"
    autoload :NonStandard, "doorkeeper/oauth/nonstandard"
    autoload :PasswordAccessTokenRequest, "doorkeeper/oauth/password_access_token_request"
    autoload :PreAuthorization, "doorkeeper/oauth/pre_authorization"
    autoload :RefreshTokenRequest, "doorkeeper/oauth/refresh_token_request"
    autoload :Scopes, "doorkeeper/oauth/scopes"
    autoload :Token, "doorkeeper/oauth/token"
    autoload :TokenIntrospection, "doorkeeper/oauth/token_introspection"
    autoload :TokenRequest, "doorkeeper/oauth/token_request"
    autoload :TokenResponse, "doorkeeper/oauth/token_response"

    module ClientAuthentication
      autoload :None, "doorkeeper/oauth/client_authentication/none"
      autoload :ClientSecretBasic, "doorkeeper/oauth/client_authentication/client_secret_basic"
      autoload :ClientSecretPost, "doorkeeper/oauth/client_authentication/client_secret_post"
    end

    module Authorization
      autoload :Code, "doorkeeper/oauth/authorization/code"
      autoload :Context, "doorkeeper/oauth/authorization/context"
      autoload :Token, "doorkeeper/oauth/authorization/token"
      autoload :URIBuilder, "doorkeeper/oauth/authorization/uri_builder"
    end

    module ClientCredentials
      autoload :Validator, "doorkeeper/oauth/client_credentials/validator"
      autoload :Creator, "doorkeeper/oauth/client_credentials/creator"
      autoload :Issuer, "doorkeeper/oauth/client_credentials/issuer"
    end

    module Helpers
      autoload :ScopeChecker, "doorkeeper/oauth/helpers/scope_checker"
      autoload :URIChecker, "doorkeeper/oauth/helpers/uri_checker"
      autoload :UniqueToken, "doorkeeper/oauth/helpers/unique_token"
    end

    module Hooks
      autoload :Context, "doorkeeper/oauth/hooks/context"
    end
  end

  module Models
    autoload :Accessible, "doorkeeper/models/concerns/accessible"
    autoload :Expirable, "doorkeeper/models/concerns/expirable"
    autoload :ExpirationTimeSqlMath, "doorkeeper/models/concerns/expiration_time_sql_math"
    autoload :Orderable, "doorkeeper/models/concerns/orderable"
    autoload :PolymorphicResourceOwner, "doorkeeper/models/concerns/polymorphic_resource_owner"
    autoload :Scopes, "doorkeeper/models/concerns/scopes"
    autoload :Reusable, "doorkeeper/models/concerns/reusable"
    autoload :ResourceOwnerable, "doorkeeper/models/concerns/resource_ownerable"
    autoload :Revocable, "doorkeeper/models/concerns/revocable"
    autoload :SecretStorable, "doorkeeper/models/concerns/secret_storable"
  end

  module Orm
    autoload :ActiveRecord, "doorkeeper/orm/active_record"
  end

  module Rails
    autoload :Helpers, "doorkeeper/rails/helpers"
    autoload :Routes, "doorkeeper/rails/routes"
  end

  module SecretStoring
    autoload :Base, "doorkeeper/secret_storing/base"
    autoload :Plain, "doorkeeper/secret_storing/plain"
    autoload :Sha256Hash, "doorkeeper/secret_storing/sha256_hash"
    autoload :BCrypt, "doorkeeper/secret_storing/bcrypt"
  end

  class << self
    attr_reader :orm_adapter

    def configure(&block)
      @config = Config::Builder.new(&block).build
      setup
      @config
    end

    # @return [Doorkeeper::Config] configuration instance
    #
    def configuration
      @config || configure
    end

    def configured?
      !@config.nil?
    end

    alias config configuration

    def setup
      setup_orm_adapter

      # Deprecated, will be removed soon
      unless configuration.orm == :active_record
        setup_orm_models
        setup_application_owner
      end
    end

    def setup_orm_adapter
      @orm_adapter = "doorkeeper/orm/#{configuration.orm}".classify.constantize
    rescue NameError => e
      raise e, "ORM adapter not found (#{configuration.orm})", <<-ERROR_MSG.strip_heredoc
        [DOORKEEPER] ORM adapter not found (#{configuration.orm}), or there was an error
        trying to load it.

        You probably need to add the related gem for this adapter to work with
        doorkeeper.
      ERROR_MSG
    end

    def run_orm_hooks
      config.clear_cache!

      if @orm_adapter.respond_to?(:run_hooks)
        @orm_adapter.run_hooks
      else
        ::Kernel.warn <<~MSG.strip_heredoc
          [DOORKEEPER] ORM "#{configuration.orm}" should move all it's setup logic under `#run_hooks` method for
          the #{@orm_adapter.name}. Later versions of Doorkeeper will no longer support `setup_orm_models` and
          `setup_application_owner` API.
        MSG
      end
    end

    def setup_orm_models
      @orm_adapter.initialize_models!
    end

    def setup_application_owner
      @orm_adapter.initialize_application_owner!
    end

    def authenticate(request, methods = Doorkeeper.config.access_token_methods)
      OAuth::Token.authenticate(request, *methods)
    end

    def gem_version
      ::Gem::Version.new(::Doorkeeper::VERSION::STRING)
    end
  end
end
