module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
    end

    class InvalidRequestStrategy < DoorkeeperError
    end

    class MissingRequestStrategy < DoorkeeperError
    end
  end
end
