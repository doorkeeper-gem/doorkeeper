module Doorkeeper
  class ExceptionRaiser
    def initialize(error)
      @error = error
    end

    def raise_if_handled
      return unless raise_errors?

      raise_invalid_token_error if error.is_a? OAuth::InvalidTokenResponse
      raise Doorkeeper::Errors::TokenForbidden, error.description if error.is_a? OAuth::ForbiddenTokenResponse
    end

    private

    attr_reader :error

    def raise_invalid_token_error
      errors = {
          expired: Doorkeeper::Errors::TokenExpired,
          revoked: Doorkeeper::Errors::TokenRevoked,
          unknown: Doorkeeper::Errors::TokenUnknown
      }

      raise errors[error.reason], error.description
    end

    def raise_errors?
      Doorkeeper.configuration.handle_auth_errors == :raise
    end
  end
end
