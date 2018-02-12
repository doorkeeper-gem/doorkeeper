module Doorkeeper
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    # Semantic versioning
    MAJOR = 4
    MINOR = 3
    TINY = 0

    # Full version number
    STRING = [MAJOR, MINOR, TINY].compact.join('.')
  end
end
