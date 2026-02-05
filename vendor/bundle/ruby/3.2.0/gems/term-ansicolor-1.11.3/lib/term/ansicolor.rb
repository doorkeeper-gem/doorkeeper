require 'tins/xt/full'
require 'tins/xt/ask_and_send'

module Term

  # The ANSIColor module can be used for namespacing and mixed into your own
  # classes.
  module ANSIColor
    require 'term/ansicolor/version'
    require 'term/ansicolor/attribute'
    require 'term/ansicolor/rgb_triple'
    require 'term/ansicolor/hsl_triple'
    require 'term/ansicolor/ppm_reader'
    require 'term/ansicolor/attribute/text'
    require 'term/ansicolor/attribute/color8'
    require 'term/ansicolor/attribute/intense_color8'
    require 'term/ansicolor/attribute/color256'
    require 'term/ansicolor/movement'
    include Term::ANSIColor::Movement
    require 'term/ansicolor/hyperlink'
    include Term::ANSIColor::Hyperlink
    include Term::ANSIColor::Attribute::Underline

    # Returns true, if the coloring function of this module
    # is switched on, false otherwise.
    def self.coloring?
      @coloring
    end

    # Turns the coloring on or off globally, so you can easily do
    # this for example:
    #   Term::ANSIColor::coloring = STDOUT.isatty
    def self.coloring=(val)
      @coloring = !!val
    end
    self.coloring = true

    # Returns true, if the tue coloring mode of this module is switched on,
    # false otherwise.
    def self.true_coloring?
      @true_coloring
    end

    # Turns the true coloring mode on or off globally, that will display 24-bit
    # colors if your terminal supports it:
    #  Term::ANSIColor::true_coloring = ENV['COLORTERM'] =~ /\A(truecolor|24bit)\z/
    def self.true_coloring=(val)
      @true_coloring = !!val
    end
    self.true_coloring = false

    # Regular expression that is used to scan for ANSI-Attributes while
    # uncoloring strings.
    COLORED_REGEXP = /\e\[(?:(?:[349]|10)[0-7]|[0-9]|[34]8;(5;\d{1,3}|2;\d{1,3}(;\d{1,3}){2})|4:\d|53)?m/

    # Returns an uncolored version of the string, that is all ANSI-Attributes
    # are stripped from the string.
    def uncolor(string = nil) # :yields:
      if block_given?
        yield.to_str.gsub(COLORED_REGEXP, '')
      elsif string.respond_to?(:to_str)
        string.to_str.gsub(COLORED_REGEXP, '')
      elsif respond_to?(:to_str)
        to_str.gsub(COLORED_REGEXP, '')
      else
        ''.dup
      end.extend(Term::ANSIColor)
    end

    alias uncolored uncolor

    def apply_code(code, string = nil, &block)
      result = ''.dup
      result << "\e[#{code}m" if Term::ANSIColor.coloring?
      if block_given?
        result << yield.to_s
      elsif string.respond_to?(:to_str)
        result << string.to_str
      elsif respond_to?(:to_str)
        result << to_str
      else
        return result # only switch on
      end
      result << "\e[0m" if Term::ANSIColor.coloring?
      result.extend(Term::ANSIColor)
    end

    def apply_attribute(name, string = nil, &block)
      attribute = Attribute[name] or
        raise ArgumentError, "unknown attribute #{name.inspect}"
      apply_code(attribute.code, string, &block)
    end

    # Return +string+ or the result string of the given +block+ colored with
    # color +name+. If string isn't a string only the escape sequence to switch
    # on the color +name+ is returned.
    def color(name, string = nil, &block)
      apply_attribute(name, string, &block)
    end

    # Return +string+ or the result string of the given +block+ with a
    # background colored with color +name+. If string isn't a string only the
    # escape sequence to switch on the color +name+ is returned.
    def on_color(name, string = nil, &block)
      attribute = Attribute[name] or
        raise ArgumentError, "unknown attribute #{name.inspect}"
      attribute = attribute.dup
      attribute.background = true
      apply_attribute(attribute, string, &block)
    end

    class << self
      # Returns an array of all Term::ANSIColor attributes as symbols.
      def term_ansicolor_attributes
        ::Term::ANSIColor::Attribute.attributes.map(&:name)
      end

      alias attributes term_ansicolor_attributes
    end

    # Returns an array of all Term::ANSIColor attributes as symbols.
    def  term_ansicolor_attributes
      ::Term::ANSIColor.term_ansicolor_attributes
    end

    alias attributes term_ansicolor_attributes

    extend self
  end
end
