# frozen_string_literal: false

module Tins
  # A class to represent durations with support for formatting and parsing time
  # intervals.
  class Duration
    include Comparable

    # Returns the number of seconds represented by the given duration string
    # according to the provided template format.
    #
    # @param [String] string The duration string to parse.
    # @param [String] template for the duration format, see {#format}.
    #   Default: '%S%d+%h:%m:%s.%f'
    #
    # @return [Integer, Float] The number of (fractional) seconds of the duration.
    #
    # @raise [ArgumentError] If the string doesn't match the expected template format
    #
    # @example Basic parsing
    #   Tins::Duration.parse('6+05:04:03', template: '%S%d+%h:%m:%s') # => 536643
    #   Tins::Duration.parse('6+05:04:03.21', template: '%S%d+%h:%m:%s.%f') # => 536643.21
    #
    # @example Parsing negative durations
    #   Tins::Duration.parse('-6+05:04:03', template: '%S%d+%h:%m:%s') # => -536643
    #
    # @example Custom template parsing
    #   Tins::Duration.parse('05:04:03.21', template: '%h:%m:%s.%f') # => 18243.21
    #
    # The parser supports the following directives in templates:
    # - `%S` - Sign indicator (optional negative sign)
    # - `%d` - Days component (integer)
    # - `%h` - Hours component (integer)
    # - `%m` - Minutes component (integer)
    # - `%s` - Seconds component (integer)
    # - `%f` - Fractional seconds component (decimal)
    # - `%%` - Literal percent character
    #
    # The parser is greedy and consumes as much of the input string as possible
    # for each directive.
    # If a directive expects a specific format but doesn't find it, an
    # ArgumentError is raised.
    def self.parse(string, template: '%S%d+%h:%m:%s.%f')
      s, t  = string.to_s.dup, template.dup
      d, sd = 0, 1
      loop do
        t.sub!(/\A(%[Sdhmsf%]|.)/) { |directive|
          case directive
          when '%S' then s.sub!(/\A-?/)   { sd *= -1 if _1 == ?-; '' }
          when '%d' then s.sub!(/\A\d+/)  { d += 86_400 * _1.to_i; '' }
          when '%h' then s.sub!(/\A\d+/)  { d += 3_600 * _1.to_i; '' }
          when '%m' then s.sub!(/\A\d+/)  { d += 60 * _1.to_i; '' }
          when '%s' then s.sub!(/\A\d+/)  { d += _1.to_i; '' }
          when '%f' then s.sub!(/\A\d+/)  { d += Float(?. + _1); '' }
          when '%%' then
            if s[0] == ?%
              s[0] = ''
            else
              raise "expected %s, got #{s.inspect}"
            end
          else
            if directive == s[0]
              s[0] = ''
            else
              raise ArgumentError, "expected #{t.inspect}, got #{s.inspect}"
            end
          end
          ''
        } or break
      end
      sd * d
    end

    # Initializes a new Duration object with the specified number of seconds.
    #
    # @param seconds [ Integer, Float ] the total number of seconds to
    # represent
    def initialize(seconds)
      @negative         = seconds < 0
      seconds           = seconds.abs
      @original_seconds = seconds
      @days, @hours, @minutes, @seconds, @fractional_seconds =
        [ 86_400, 3600, 60, 1, 0 ].inject([ [], seconds ]) {|(r, s), d|
          if d > 0
            dd, rest = s.divmod(d)
            r << dd
            [ r, rest ]
          else
            r << s
          end
        }
    end

    # Converts the original seconds value to a floating-point number.
    #
    # @return [Float] the original seconds value as a floating-point number
    def to_f
      @original_seconds.to_f
    end

    # The <=> method compares this object with another object after converting
    # both to floats.
    #
    # @param other [Object] the object to compare with
    #
    # @return [Integer] -1 if this object is less than other, 0 if they are
    # equal, 1 if this object is greater than other
    def <=>(other)
      to_f <=> other.to_f
    end

    # Returns true if the duration is negative.
    #
    # @return [TrueClass, FalseClass] true if the duration represents a
    # negative time interval, false otherwise
    def negative?
      @negative
    end

    # Returns true if the duration includes days, false otherwise.
    #
    # @return [TrueClass, FalseClass] true if the duration has any days, false
    # otherwise
    def days?
      @days > 0
    end

    # Returns true if the duration has any hours component
    #
    # @return [TrueClass, FalseClass] true if hours are present, false
    # otherwise
    def hours?
      @hours > 0
    end

    # Returns true if the duration has minutes, false otherwise.
    #
    # @return [TrueClass, FalseClass] true if minutes are greater than 0, false otherwise
    def minutes?
      @minutes > 0
    end

    # Returns true if the duration has a positive seconds component.
    #
    # @return [TrueClass, FalseClass] true if seconds are greater than zero,
    # false otherwise
    def seconds?
      @seconds > 0
    end

    # Returns true if the duration includes fractional seconds.
    #
    # @return [TrueClass, FalseClass] true if fractional seconds are present,
    # false otherwise
    def fractional_seconds?
      @fractional_seconds > 0
    end

    # Formats the duration according to the given template and precision.
    #
    # The template string supports the following directives:
    # - `%S` - Sign indicator (negative sign if duration is negative)
    # - `%d` - Days component
    # - `%h` - Hours component (zero-padded to 2 digits)
    # - `%m` - Minutes component (zero-padded to 2 digits)
    # - `%s` - Seconds component (zero-padded to 2 digits)
    # - `%f` - Fractional seconds component (without the leading decimal point)
    # - `%D` - Smart format (automatically includes days, fractional seconds, and sign)
    # - `%%` - Literal percent character
    #
    # When using `%f`, the fractional part will be formatted according to the precision parameter.
    #
    # @param template [String] the format template to use for formatting
    #   Default: '%S%d+%h:%m:%s.%f'
    # @param precision [Integer] the precision to use for fractional seconds
    #   When nil, uses default formatting with 6 decimal places
    #
    # @return [String] the formatted duration string
    #
    # @example Basic formatting
    #   duration = Tins::Duration.new(93784.123)
    #   duration.format('%d+%h:%m:%s.%f') # => "1+02:03:04.123000"
    #
    # @example Smart format
    #   duration.format('%D') # => "1+02:03:04.123"
    #
    # @example Custom precision
    #   duration.format('%s.%f', precision: 2) # => "04.12"
    def format(template = '%S%d+%h:%m:%s.%f', precision: nil)
      result = template.gsub(/%[DdhmSs%]/) { |directive|
        case directive
        when '%S' then ?- if negative?
        when '%d' then @days
        when '%h' then '%02u' % @hours
        when '%m' then '%02u' % @minutes
        when '%s' then '%02u' % @seconds
        when '%D' then format_smart
        when '%%' then '%'
        end
      }
      if result.include?('%f')
        if precision
          fractional_seconds = "%.#{precision}f" % @fractional_seconds
        else
          fractional_seconds = '%f' % @fractional_seconds
        end
        result.gsub!('%f', fractional_seconds[2..-1])
      end
      result
    end

    # The to_s method returns a string representation of the duration by
        # formatting it using the smart format method
    #
    # @return [String] the formatted duration string
    def to_s
      format_smart
    end

    private

    # The format_smart method provides intelligent formatting based on the
    # duration's components. It automatically determines which components are
    # present and formats them accordingly, making it ideal for human-readable
    # output where you want to avoid showing zero values.
    #
    # The smart format follows these rules:
    # - If days are present, includes the day component (e.g., "1+02:03:04") -
    # If fractional seconds are present, includes them with 3 decimal places
    # (e.g., ".123")
    # - If the duration is negative, includes the sign prefix
    #
    # This method is used internally by #to_s and can also be called directly
    # for smart formatting using the %D directive.
    #
    # @return [String] a formatted duration string using intelligent component
    # inclusion
    def format_smart
      template  = '%h:%m:%s'
      precision = nil
      if days?
        template.prepend '%d+'
      end
      if fractional_seconds?
        template << '.%f'
        precision = 3
      end
      template.prepend '%S'
      format template, precision: precision
    end
  end
end
