# frozen_string_literal: true

module Doorkeeper
  module VERSION
    # Semantic versioning
    MAJOR = 5
    MINOR = 8
    TINY = 2
    PRE = nil

    # Full version number
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
