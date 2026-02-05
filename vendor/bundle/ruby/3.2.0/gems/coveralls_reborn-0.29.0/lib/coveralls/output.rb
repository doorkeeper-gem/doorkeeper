# frozen_string_literal: true

module Coveralls
  #
  # Public: Methods for formatting strings with Term::ANSIColor.
  # Does not utilize monkey-patching and should play nicely when
  # included with other libraries.
  #
  # All methods are module methods and should be called on
  # the Coveralls::Output module.
  #
  # Examples
  #
  #   Coveralls::Output.format("Hello World", :color => "cyan")
  #   # => "\e[36mHello World\e[0m"
  #
  #   Coveralls::Output.print("Hello World")
  #   # Hello World => nil
  #
  #   Coveralls::Output.puts("Hello World", :color => "underline")
  #   # Hello World
  #   # => nil
  #
  # To silence output completely:
  #
  #   Coveralls::Output.silent = true
  #
  # or set this environment variable:
  #
  #   COVERALLS_SILENT
  #
  # To disable color completely:
  #
  #   Coveralls::Output.no_color = true

  module Output
    class << self
      attr_accessor :silent, :no_color
      attr_writer :output
    end

    module_function

    def output
      (defined?(@output) && @output) || $stdout
    end

    def no_color?
      defined?(@no_color) && @no_color
    end

    # Public: Formats the given string with the specified color
    # through Term::ANSIColor
    #
    # string  - the text to be formatted
    # options - The hash of options used for formatting the text:
    #           :color - The color to be passed as a method to
    #                    Term::ANSIColor
    #
    # Examples
    #
    #   Coveralls::Output.format("Hello World!", :color => "cyan")
    #   # => "\e[36mHello World\e[0m"
    #
    # Returns the formatted string.
    def format(string, options = {})
      unless no_color?
        require 'term/ansicolor'
        options[:color]&.split(/\s/)&.reverse_each do |color|
          next unless Term::ANSIColor.respond_to?(color.to_sym)

          string = Term::ANSIColor.send(color.to_sym, string)
        end
      end
      string
    end

    # Public: Passes .format to Kernel#puts
    #
    # string  - the text to be formatted
    # options - The hash of options used for formatting the text:
    #           :color - The color to be passed as a method to
    #                    Term::ANSIColor
    #
    #
    # Example
    #
    #   Coveralls::Output.puts("Hello World", :color => "cyan")
    #
    # Returns nil.
    def puts(string, options = {})
      return if silent?

      (options[:output] || output).puts format(string, options)
    end

    # Public: Passes .format to Kernel#print
    #
    # string  - the text to be formatted
    # options - The hash of options used for formatting the text:
    #           :color - The color to be passed as a method to
    #                    Term::ANSIColor
    #
    # Example
    #
    #   Coveralls::Output.print("Hello World!", :color => "underline")
    #
    # Returns nil.
    def print(string, options = {})
      return if silent?

      (options[:output] || output).print format(string, options)
    end

    def silent?
      ENV['COVERALLS_SILENT'] || (defined?(@silent) && @silent)
    end
  end
end
