require 'tins/xt/time_dummy'
require 'tins/xt/date_time_dummy'
require 'tins/xt/date_dummy'

module Tins
  # TimeFreezer provides a mechanism to temporarily freeze time across multiple
  # time-related classes.
  #
  # This module allows you to temporarily replace the behavior of Time, DateTime,
  # and Date classes with dummy implementations that always return a specific
  # time value. This is particularly useful for testing code that depends on
  # current time values.
  #
  # @example Basic usage
  #   Tins::TimeFreezer.freeze(Time.new(2023, 1, 1)) do
  #     # All Time, DateTime, and Date calls will return the frozen time
  #     puts Time.now  # => 2023-01-01 00:00:00 +0000
  #   end
  #
  # @example With DateTime and Date
  #   Tins::TimeFreezer.freeze(Time.new(2023, 1, 1)) do
  #     puts DateTime.now  # => 2023-01-01T00:00:00+00:00
  #     puts Date.today    # => 2023-01-01
  #   end
  #
  # @example Using time string (will be parsed by Time.parse)
  #   Tins::TimeFreezer.freeze("2023-01-01 12:00:00") do
  #     # Time.now will return the parsed time
  #     puts Time.now  # => 2023-01-01 12:00:00 +0000
  #   end
  module TimeFreezer
    # Freezes time for the duration of the given block.
    #
    # This method temporarily replaces the behavior of Time, DateTime, and Date
    # classes with dummy implementations that always return the specified time
    # value.
    #
    # @param time [Time, DateTime, Date] The time value to freeze all
    # time-related classes to
    # @yield [] The block of code to execute with frozen time
    # @return [Object] The return value of the yielded block
    def self.freeze(time)
      Time.dummy(time) do
        DateTime.dummy(time) do
          Date.dummy(time) do
            yield
          end
        end
      end
    end
  end
end
