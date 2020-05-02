# frozen_string_literal: true

module Doorkeeper
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    # Semantic versioning
    MAJOR = 5
    MINOR = 0
    TINY = 3
    PRE = nil

    # Full version number
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
