module Appraisal
  class Customize
    def initialize(heading: nil, single_quotes: false)
      @@heading = heading
      @@single_quotes = single_quotes
    end

    def self.heading
      @@heading ||= nil
    end

    def self.single_quotes
      @@single_quotes ||= false
    end
  end
end
