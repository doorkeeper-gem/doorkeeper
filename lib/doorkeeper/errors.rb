# frozen_string_literal: true

module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
      def type
        message
      end

      def self.translate_options
        {}
      end
    end

    class InvalidGrantReuse < DoorkeeperError
      def type
        :invalid_grant
      end
    end

    class InvalidTokenStrategy < DoorkeeperError
      def type
        :unsupported_grant_type
      end
    end

    # Raised when a request uses more than one client authentication method,
    # which RFC 6749 §2.3 explicitly forbids ("The client MUST NOT use more
    # than one authentication method in each request").
    class MultipleClientAuthMethods < DoorkeeperError
      def type
        :invalid_request
      end

      def reason
        :multiple_client_auth_methods
      end
    end

    class MissingRequiredParameter < DoorkeeperError
      attr_reader :missing_param

      def initialize(missing_param)
        super
        @missing_param = missing_param
      end

      def type
        :invalid_request
      end
    end

    # Raised when the `scope` parameter is present but not a string — e.g.
    # `scope[a]=b`, which Rack parses into a Hash. Its octets cannot be split
    # into scope tokens, so the request is malformed (RFC 6749 §3.3) and must
    # be answered with `invalid_request` rather than an unhandled 500.
    class InvalidScopeParameter < DoorkeeperError
      def type
        :invalid_request
      end

      # Maps to `invalid_request.unknown` ("... or is otherwise malformed").
      # Without a reason the token endpoint would translate `nil` and return a
      # blank error_description.
      def reason
        :unknown
      end
    end

    class BaseResponseError < DoorkeeperError
      attr_reader :response

      def initialize(response)
        @response = response
      end

      def self.name_for_response
        name.demodulize.underscore.to_sym
      end
    end

    class InvalidCodeChallengeMethod < BaseResponseError
      def self.translate_options
        challenge_methods = Doorkeeper.config.pkce_code_challenge_methods_supported
        {
          challenge_methods: challenge_methods.join(", "),
          count: challenge_methods.length,
        }
      end
    end

    UnableToGenerateToken = Class.new(DoorkeeperError)
    TokenGeneratorNotFound = Class.new(DoorkeeperError)
    NoOrmCleaner = Class.new(DoorkeeperError)
    MissingConfigurationBuilderClass = Class.new(DoorkeeperError)

    # Raised when resource_indicator_validator is configured but the required
    # `resource` column has not been added to the database. Provides an
    # actionable message pointing to the generator.
    #
    # `#type` returns `:server_error` so the token endpoint (which rescues
    # DoorkeeperError and builds an OAuth error response from `#type`) emits a
    # spec-compliant error code; the actionable message is retained on the
    # exception for logs rather than being sent as the `error` value.
    class MissingResourceColumn < DoorkeeperError
      def initialize(table)
        super(
          "resource_indicator_validator is configured but the `resource` column is missing from " \
          "the #{table} table. Run `rails generate doorkeeper:resource_indicators` and apply the migration.",
        )
      end

      def type
        :server_error
      end
    end

    # Raised when `Application#rotate_secret!(revoke_tokens: true)` is called
    # inside a transaction the rotation would join. The revocation of the
    # application's tokens and grants must run after the rotation's row lock
    # has been released — under it, the lock order is the reverse of the one
    # token requests take, and the two deadlock — and inside a joined
    # transaction that lock is held until the caller's commit, which the
    # rotation cannot wait for. The caller commits first, then revokes
    # through `#revoke_issued_credentials!`.
    class SecretRotationInTransaction < DoorkeeperError
      def initialize
        super(
          "`rotate_secret!(revoke_tokens: true)` cannot run inside an open transaction: the " \
          "revocation must wait for the rotation's row lock to be released, and a transaction " \
          "it joined holds that lock until its own commit. Rotate without `revoke_tokens`, " \
          "then call `#revoke_issued_credentials!` once the transaction has committed.",
        )
      end
    end

    # Raised when `Application#rotate_secret!` or `#clear_old_secret!` is
    # called without client secret rotation being available — either the
    # `enable_secret_rotation` option is off or the rotation columns have not
    # been added. Rotating under those conditions would drop the superseded
    # secret rather than retain it, cutting off every client the caller meant
    # to give a grace period, so it fails loudly instead of silently doing the
    # opposite of what was asked.
    class SecretRotationNotEnabled < DoorkeeperError
      def initialize(table)
        super(
          "Client secret rotation is not enabled. Add `enable_secret_rotation` to your Doorkeeper " \
          "initializer and make sure the `old_secret` and `old_secret_created_at` columns exist " \
          "on the #{table} table (`rails generate doorkeeper:secret_rotation`), then replace a " \
          "secret without a grace period with `#rotate_secret!(revoke_old: true)`. Not with " \
          "`#renew_secret`, which writes the current secret alone: where an earlier rotation left " \
          "an `old_secret` on this row, that credential is still there, and authenticates again " \
          "the moment rotation is available.",
        )
      end
    end

    InvalidRequest = Class.new(BaseResponseError)
    InvalidToken = Class.new(BaseResponseError)
    InvalidClient = Class.new(BaseResponseError)
    InvalidScope = Class.new(BaseResponseError)
    InvalidRedirectUri = Class.new(BaseResponseError)
    InvalidGrant = Class.new(BaseResponseError)
    # RFC 8707 error: the requested resource is invalid, missing, unknown, or malformed.
    # Raised bare (no arguments) as a signal inside ResourceIndicatorValidator,
    # then rescued and surfaced through the validation framework. Also raised
    # with a response by ErrorResponse#raise_exception! so that controller
    # rescue handlers can extract #response for translated error descriptions.
    class InvalidTarget < BaseResponseError
      def initialize(response = nil)
        super
      end
    end

    UnauthorizedClient = Class.new(BaseResponseError)
    UnsupportedResponseType = Class.new(BaseResponseError)
    UnsupportedResponseMode = Class.new(BaseResponseError)

    AccessDenied = Class.new(BaseResponseError)
    ServerError = Class.new(BaseResponseError)

    TokenExpired = Class.new(InvalidToken)
    TokenRevoked = Class.new(InvalidToken)
    TokenUnknown = Class.new(InvalidToken)
    TokenForbidden = Class.new(InvalidToken)
  end
end
