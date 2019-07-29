# frozen_string_literal: true

module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
      def type
        message
      end
    end

    class InvalidAuthorizationStrategy < DoorkeeperError
      def type
        :unsupported_response_type
      end
    end

    class InvalidTokenReuse < DoorkeeperError
      def type
        :invalid_request
      end
    end

    class InvalidGrantReuse < DoorkeeperError
      def type
        :invalid_grant
      end
    end

    # in case client authorization is denied
    class AccessDenied < DoorkeeperError
      def type
        :access_denied
      end
    end

    class InvalidTokenStrategy < DoorkeeperError
      def type
        :unsupported_grant_type
      end
    end

    class MissingRequestStrategy < DoorkeeperError
      def type
        :invalid_request
      end
    end

    # in case client is still not authorized
    class AuthorizationPending < DoorkeeperError
      def type
        :authorization_pending
      end
    end

    # in case client is polling too often
    class SlowDown < DoorkeeperError
      def type
        :slow_down
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

    InvalidToken = Class.new(BaseResponseError)
    TokenExpired = Class.new(InvalidToken)
    TokenRevoked = Class.new(InvalidToken)
    TokenUnknown = Class.new(InvalidToken)
    TokenForbidden = Class.new(InvalidToken)
  end
end
