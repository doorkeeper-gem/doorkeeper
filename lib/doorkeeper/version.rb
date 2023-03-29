# frozen_string_literal: true

module Doorkeeper
  module VERSION
    # Semantic versioning
    MAJOR = 5
    MINOR = 6
    TINY = 6
    PRE = nil

    # Full version number
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
