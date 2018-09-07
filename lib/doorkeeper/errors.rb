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

    class BaseResponseError < DoorkeeperError
      attr_reader :response

      def initialize(response)
        @response = response
      end
    end

    UnableToGenerateToken = Class.new(DoorkeeperError)
    TokenGeneratorNotFound = Class.new(DoorkeeperError)

    InvalidToken = Class.new BaseResponseError
    TokenExpired = Class.new InvalidToken
    TokenRevoked = Class.new InvalidToken
    TokenUnknown = Class.new InvalidToken
    TokenForbidden = Class.new InvalidToken
  end
end
