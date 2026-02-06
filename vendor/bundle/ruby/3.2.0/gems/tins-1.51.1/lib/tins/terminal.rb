begin
  require 'io/console'
rescue LoadError
end

module Tins
  # A module for handling terminal-related functionality and terminal
  # input/output operations.
  #
  # Provides methods for interacting with terminal capabilities, reading from
  # standard input, and managing terminal sessions.
  module Terminal
    # Returns the window size of the console.
    #
    # This method attempts to retrieve the terminal window dimensions by
    # accessing the console object and its winsize method.
    #
    # @return [ Array<Integer> ] an array containing the rows and columns
    #   of the terminal window, or an empty array if the console is not
    #   available or does not support winsize querying
    def winsize
      if IO.respond_to?(:console)
        c = IO.console
        if c.respond_to?(:winsize)
          c.winsize
        else
          []
        end
      else
        []
      end
    end

    # Returns the number of rows (lines) in the terminal window.
    #
    # Attempts to determine the terminal size by checking various sources in
    # order of preference: window size, stty command output, tput command
    # output, and defaults to 25 lines if all methods fail.
    #
    # @return [ Integer ] the number of terminal rows, or 25 as fallback
    def rows
      winsize[0] || `stty size 2>/dev/null`.split[0].to_i.nonzero? ||
        `tput lines 2>/dev/null`.to_i.nonzero? || 25
    end

    alias lines rows

    # Returns the number of columns in the terminal
    #
    # This method attempts to determine the terminal width by checking various sources
    # in order of preference: system winsize information, stty output, tput output,
    # and falls back to a default of 80 columns if none are available
    #
    # @return [Integer] the number of columns in the terminal or 80 as fallback
    def columns
      winsize[1] || `stty size 2>/dev/null`.split[1].to_i.nonzero? ||
        `tput cols 2>/dev/null`.to_i.nonzero? || 80
    end

    alias cols columns

    extend self
  end
end
