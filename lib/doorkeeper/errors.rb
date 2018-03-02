module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
      attr_accessor :status

      def initialize(message=nil, status: nil)
        super(message)
        @status = status
      end

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

    class UnableToGenerateToken < DoorkeeperError
    end

    class TokenGeneratorNotFound < DoorkeeperError
    end
  end
end
