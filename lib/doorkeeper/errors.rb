module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
    end

    class InvalidAuthorizationStrategy < DoorkeeperError
    end

    class InvalidTokenReuse < DoorkeeperError
    end

    class InvalidGrantReuse < DoorkeeperError
    end

    class InvalidTokenStrategy < DoorkeeperError
    end

    class MissingRequestStrategy < DoorkeeperError
    end

    class UnableToGenerateToken < DoorkeeperError
    end

    class TokenGeneratorNotFound < DoorkeeperError
    end
  end
end
