module Doorkeeper
  module Errors
    class DoorkeeperError < StandardError
    end

    class InvalidRequestStrategy < DoorkeeperError
    end
  end
end
