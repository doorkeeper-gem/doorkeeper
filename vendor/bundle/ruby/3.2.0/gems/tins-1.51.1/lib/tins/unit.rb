require 'strscan'
require 'bigdecimal'

module Tins
  # A module for parsing and formatting unit specifications with support for
  # various prefix types and unit formats.
  #
  # @example Basic usage
  #   Tins::Unit.parse('1.5 GB').round # => 1610612736
  #   Tins::Unit.format(1610612736, unit: 'B') # => "1.500000 GB"
  #   Tins::Unit.parse('1000 mb', prefix: 1000).round # => 1000000000
  module Unit
    # A simple data structure representing a unit prefix with name, scaling step,
    # multiplier, and fraction flag.
    Prefix = Struct.new(:name, :step, :multiplier, :fraction)

    # An array of prefix objects for lowercase decimal prefixes (k, M, G...)
    # based on 1000-step increments.
    PREFIX_LC = [
      '', 'k', 'm', 'g', 't', 'p', 'e', 'z', 'y',
    ].each_with_index.map { |n, i| Prefix.new(n.freeze, 1000, 1000 ** i, false) }.freeze

    # An array of prefix objects for uppercase binary prefixes (K, M, G...) based
    # on 1024-step increments.
    PREFIX_UC = [
      '', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y',
    ].each_with_index.map { |n, i| Prefix.new(n.freeze, 1024, 1024 ** i, false) }.freeze

    # An array of prefix objects for uppercase binary prefixes (Ki, Mi, Gi...) based
    # on 1024-step increments.
    PREFIX_IEC_UC = [
      '', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi',
    ].each_with_index.map { |n, i| Prefix.new(n.freeze, 1024, 1024 ** i, false) }.freeze

    # An array of prefix objects for uppercase SI unit prefixes (K, M, G...) based
    # on 1000-step increments.
    PREFIX_SI_UC = [
      '', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y',
    ].each_with_index.map { |n, i| Prefix.new(n.freeze, 1000, 1000 ** i, false) }.freeze

    # An array of prefix objects for fractional prefixes (m, µ, n...) based on
    # 1000-step decrements.
    PREFIX_F = [
      '', 'm', 'µ', 'n', 'p', 'f', 'a', 'z', 'y',
    ].each_with_index.map { |n, i| Prefix.new(n.freeze, 1000, 1000 ** -i, true) }.freeze

    # A custom exception class for parser errors that inherits from ArgumentError
    class ParserError < ArgumentError; end

    module_function

    # The prefixes method returns an array of prefix objects based on the given
    # identifier.
    #
    # This method maps different identifier symbols and values to predefined
    # arrays of prefix objects, allowing for flexible configuration of unit
    # prefixes.
    #
    # @param identifier [Symbol, Integer, Array] the identifier specifying which
    #   prefix set to return
    # @return [Array] an array of prefix objects corresponding to the identifier
    def prefixes(identifier)
      case identifier
      when :uppercase, :uc, 1024
        PREFIX_UC
      when :iec_uppercase, :iec_uc
        PREFIX_IEC_UC
      when :lowercase, :lc, 1000
        PREFIX_LC
      when :fraction, :f, :si_greek, 0.001
        PREFIX_F
      when :si_uc, :si_uppercase
        PREFIX_SI_UC
      when Array
        identifier
      end
    end

    # Format a value using unit prefixes and a specified format template.
    #
    # This method takes a numerical value and formats it according to the given
    # format string, inserting the appropriate unit prefix based on the specified
    # prefix type and unit identifier.
    #
    # @param value [Numeric] the numerical value to format
    # @param format [String] the format template to use for output, default is '%f %U'
    # @param prefix [Object] the prefix configuration to use, default is 1024 (binary prefixes)
    # @param unit [String, Symbol] the unit identifier to append, default is ?b (bytes)
    def format(value, format: '%f %U', prefix: 1024, unit: ?b)
      prefixes = prefixes(prefix)
      first_prefix = prefixes.first or
        raise ArgumentError, 'a non-empty array of prefixes is required'
      if value.zero?
        result = format.sub('%U', unit)
        result %= value
      else
        prefix = prefixes[
          (first_prefix.fraction ? -1 : 1) * Math.log(value.abs) / Math.log(first_prefix.step)
        ]
        result = format.sub('%U', "#{prefix.name}#{unit}")
        result %= (value / prefix.multiplier.to_f)
      end
    end

    # A parser for unit specifications that extends StringScanner
    #
    # This class is responsible for parsing strings that contain numerical values
    # followed by unit specifications, supporting various prefix types and unit
    # formats for flexible unit parsing.
    class UnitParser < StringScanner
      # A regular expression matching a number.
      NUMBER = /([+-]?
                 (?:0|[1-9]\d*)
                 (?:
                  \.\d+(?i:e[+-]?\d+) |
                 \.\d+ |
                 (?i:e[+-]?\d+)
                 )?
                )/x

                 # The initialize method sets up a new UnitParser instance with the given
                 # source string, unit identifier, and optional prefixes configuration.
                 #
                 # @param source [String] the input string to parse for units
                 # @param unit [String, Symbol] the unit identifier to look for in the source
                 # @param prefixes [Object, nil] optional prefixes configuration (can be array or symbol)
                 # @return [UnitParser] a new UnitParser instance configured with the provided parameters
                 def initialize(source, unit, prefixes = nil)
                   super source
                   if prefixes
                     @unit_re    = unit_re(Tins::Unit.prefixes(prefixes), unit)
                     @unit_lc_re = @unit_uc_re = nil
                   else
                     @unit_lc_re = unit_re(Tins::Unit.prefixes(:lc), unit)
                     @unit_uc_re = unit_re(Tins::Unit.prefixes(:uc), unit)
                     @unit_re    = nil
                   end
                   @number       = 1.0
                 end

                 # The unit_re method creates a regular expression for matching units with
                 # prefixes
                 #
                 # This method constructs a regular expression pattern that can match unit
                 # strings including their associated prefixes, which is useful for parsing
                 # formatted unit specifications in text.
                 #
                 # @param prefixes [Array] an array of prefix objects with name attributes
                 # @param unit [String] the base unit string to match against
                 #
                 # @return [Regexp] a regular expression object that can match prefixed units
                 def unit_re(prefixes, unit)
                   re = Regexp.new(
                     "(#{prefixes.reverse.map { |pre| Regexp.quote(pre.name) } * ?|})(#{unit})"
                   )
                   re.singleton_class.class_eval do
                     define_method(:prefixes) { prefixes }
                   end
                   re
                 end

                 private :unit_re

                 # The number reader method returns the value of the number attribute.
                 #
                 # @return [Object] the current value of the number attribute
                 attr_reader :number

                 # The scan method scans a regular expression against the current string
                 # scanner state.
                 #
                 # This method delegates to the parent StringScanner's scan method, but
                 # includes a guard clause to return early if the provided regular
                 # expression is nil.
                 #
                 # @param re [Regexp, nil] the regular expression to scan for
                 # @return [String, nil] the matched string if found, or nil if no match
                 def scan(re)
                   re.nil? and return
                   super
                 end

                 # The scan_number method parses a number from the current string scanner
                 # state and multiplies the internal number value by it.
                 def scan_number
                   scan(NUMBER) or return
                   @number *= BigDecimal(self[1])
                 end

                 # The scan_unit method attempts to match unit patterns against the current
                 # string and updates the internal number value by multiplying it with the
                 # corresponding prefix multiplier
                 def scan_unit
                   case
                   when scan(@unit_re)
                     prefix = @unit_re.prefixes.find { |pre| pre.name == self[1] } or return
                     @number *= prefix.multiplier
                   when scan(@unit_lc_re)
                     prefix = @unit_lc_re.prefixes.find { |pre| pre.name == self[1] } or return
                     @number *= prefix.multiplier
                   when scan(@unit_uc_re)
                     prefix = @unit_uc_re.prefixes.find { |pre| pre.name == self[1] } or return
                     @number *= prefix.multiplier
                   end
                 end

                 # The scan_char method attempts to match a character pattern against the
                 # current string scanner state.
                 #
                 # @param char [String] the character to scan for
                 # @return [String, nil] the matched string if found, or nil if no match
                 def scan_char(char)
                   scan(/#{char}/) or return
                 end

                 # The parse method is intended to be overridden by subclasses to provide
                 # specific parsing functionality.
                 #
                 # @return [Object] the parsed result
                 def parse
                   raise NotImplementedError
                 end
    end

    # A parser for unit specifications that extends StringScanner
    #
    # This class is responsible for parsing strings that contain numerical values
    # followed by unit specifications, supporting various prefix types and unit
    # formats for flexible unit parsing.
    class FormatParser < StringScanner

      # The initialize method sets up a new UnitParser instance with the given
      # format and unit parser.
      #
      # @param format [String] the format string to use for parsing
      # @param unit_parser [Tins::Unit::UnitParser] the unit parser to use for
      # parsing units
      # @return [Tins::Unit::FormatParser] a new FormatParser instance configured
      # with the provided parameters
      def initialize(format, unit_parser)
        super format
        @unit_parser = unit_parser
      end

      # The reset method resets the unit parser state.
      #
      # This method calls the superclass reset implementation and then resets
      # the internal unit parser instance to its initial state.
      def reset
        super
        @unit_parser.reset
      end

      # The location method returns a string representation of the current
      # parsing position by peeking at the next 10 characters from the unit
      # parser and inspecting them
      # @return [String] the inspected representation of the next 10 characters from the parser
      # @private
      def location
        @unit_parser.peek(10).inspect
      end

      private :location

      # The parse method parses a format string using a unit parser and returns
      # the parsed number.
      #
      # This method processes a format template by scanning for specific pattern directives
      # (%f for numbers, %U for units, %% for literal percent signs) and validates that
      # the input string matches the expected format. It handles parsing errors by raising
      # ParserError exceptions with descriptive messages about mismatches.
      #
      # @return [Float] the parsed numerical value with units applied
      # @raise [ParserError] if the format string or input string doesn't match the expected pattern
      # @raise [ParserError] if a required number or unit is missing at a specific location
      # @raise [ParserError] if literal percent signs don't match expected positions
      def parse
        reset
        until eos? || @unit_parser.eos?
          case
          when scan(/%f/)
            @unit_parser.scan_number or
              raise ParserError, "\"%f\" expected at #{location}"
          when scan(/%U/)
            @unit_parser.scan_unit or
              raise ParserError, "\"%U\" expected at #{location}"
          when scan(/%%/)
            @unit_parser.scan_char(?%) or
              raise ParserError, "#{?%.inspect} expected at #{location}"
          else
            char = scan(/./)
            @unit_parser.scan_char(char) or
              raise ParserError, "#{char.inspect} expected at #{location}"
          end
        end
        unless eos? && @unit_parser.eos?
          raise ParserError,
            "format #{string.inspect} and string "\
            "#{@unit_parser.string.inspect} do not match"
        end
        @unit_parser.number
      end
    end

    # Parse the string using the specified format and unit information
    #
    # This method takes a string and parses it according to a given format template,
    # extracting numerical values and their associated units. It supports various
    # prefix types and unit specifications for flexible parsing.
    #
    # @param string [String] the input string to parse
    # @param format [String] the format template to use for parsing (default: '%f %U')
    # @param unit [String, Symbol] the unit identifier to use (default: ?b)
    # @param prefix [Object] the prefix configuration to use (default: nil)
    #
    # @return [Object] the parsed result based on the format and unit specifications
    def parse(string, format: '%f %U', unit: ?b, prefix: nil)
      prefixes = prefixes(prefix)
      FormatParser.new(format, UnitParser.new(string, unit, prefixes)).parse
    end

    # The parse? method attempts to parse a string using the specified options
    # and returns nil if parsing fails.
    #
    # @param string [String] the string to parse
    # @param options [Hash] the options to pass to the parse method
    # @return [Object, nil] the parsed result or nil if parsing fails
    def parse?(string, **options)
      parse(string, **options)
    rescue ParserError
      nil
    end
  end
end
