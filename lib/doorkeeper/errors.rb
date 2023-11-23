# frozen_string_literal: true

module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
      def type
        message
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

    class BaseResponseError < DoorkeeperError
      attr_reader :response

      def initialize(response)
        @response = response
      end
    end

    UnableToGenerateToken = Class.new(DoorkeeperError)
    TokenGeneratorNotFound = Class.new(DoorkeeperError)
    NoOrmCleaner = Class.new(DoorkeeperError)

    ServerError = Class.new(BaseResponseError)

    InvalidRequest = Class.new(BaseResponseError)
    InvalidToken = Class.new(BaseResponseError)
    InvalidClient = Class.new(BaseResponseError)
    InvalidScope = Class.new(BaseResponseError)
    InvalidRedirectUri = Class.new(BaseResponseError)
    InvalidCodeChallengeMethod = Class.new(BaseResponseError)
    InvalidGrant = Class.new(BaseResponseError)

    UnauthorizedClient = Class.new(BaseResponseError)
    UnsupportedResponseType = Class.new(BaseResponseError)
    UnsupportedResponseMode = Class.new(BaseResponseError)

    AccessDenied = Class.new(BaseResponseError)

    TokenExpired = Class.new(InvalidToken)
    TokenRevoked = Class.new(InvalidToken)
    TokenUnknown = Class.new(InvalidToken)
    TokenForbidden = Class.new(InvalidToken)
  end
end
