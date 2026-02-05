require 'term/ansicolor/rgb_color_metrics'

module Term
  module ANSIColor
    class RGBTriple
      include Term::ANSIColor::RGBColorMetricsHelpers::WeightedEuclideanDistance

      def self.convert_value(color, max: 255)
        color.nil? and raise ArgumentError, "missing color value"
        color = Integer(color)
        (0..max) === color or raise ArgumentError,
          "color value #{color.inspect} not between 0 and #{max}"
        color
      end

      private_class_method :convert_value

      def self.from_html(html)
        case html
        when /\A#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})\z/i
          new(*$~.captures.map { |c| convert_value(c.to_i(16)) })
        when /\A#([0-9a-f])([0-9a-f])([0-9a-f])\z/i
          new(*$~.captures.map { |c| convert_value((c + c).to_i(16)) })
        end
      end

      def self.from_css(css)
        case css
        when /\A\s*rgb\(\s*([^%\s]+)\s*%\s*,\s*([^%\s]+)\s*%\s*,\s*([^%\s]+)\s*%\s*\)\z/
          new(*$~.captures.map { |c| convert_value(((Float(c) / 100) * 0xff).round) })
        when /\A\s*rgb\(\s*([^,\s]+)\s*,\s*([^,\s]+)\s*,\s*([^\)\s]+)\s*\)\z/
          new(*$~.captures.map { |c| convert_value((Float(c)).round) })
        end
      end

      def self.from_hash(options)
        new(
          convert_value(options[:red]),
          convert_value(options[:green]),
          convert_value(options[:blue])
        )
      end

      def self.from_array(array)
        new(*array)
      end

      def self.[](thing)
        case
        when thing.respond_to?(:to_rgb_triple) then thing.to_rgb_triple
        when thing.respond_to?(:to_ary)        then from_array(thing.to_ary)
        when thing.respond_to?(:to_str)
          thing = thing.to_str
          from_html(thing.sub(/\Aon_/, '')) || from_css(thing) ||
            Term::ANSIColor::HSLTriple.from_css(thing).full?(:to_rgb_triple)
        when thing.respond_to?(:to_hash)       then from_hash(thing.to_hash)
        else raise ArgumentError, "cannot convert #{thing.inspect} into #{self}"
        end
      end

      def initialize(red, green, blue)
        @values = [
          red.clamp(0, 0xff),
          green.clamp(0, 0xff),
          blue.clamp(0, 0xff),
        ]
      end

      def red
        @values[0]
      end

      def green
        @values[1]
      end

      def blue
        @values[2]
      end

      def percentages
        @percentages ||= @values.map { |v| 100 * v / 255.0 }
      end

      def red_p
        percentages[0]
      end

      def green_p
        percentages[1]
      end

      def blue_p
        percentages[2]
      end

      def invert
        self.class.new(255 - red, 255 - green, 255 - blue)
      end

      def gray?
        red != 0 && red != 0xff && red == green && green == blue && blue == red
      end

      def html
        '#%02x%02x%02x' % @values
      end

      def css(percentage: false)
        if percentage
          "rgb(%s%%,%s%%,%s%%)" % percentages
        else
          "rgb(%u,%u,%u)" % @values
        end
      end

      def to_rgb_triple
        self
      end

      def to_hsl_triple
        Term::ANSIColor::HSLTriple.from_rgb_triple(self)
      end

      attr_reader :values
      protected :values

      def to_a
        @values.dup
      end

      def ==(other)
        @values == other.to_rgb_triple.values
      end

      def color(string)
        Term::ANSIColor.color(self, string)
      end

      def distance_to(other, options = {})
        options[:metric] ||= RGBColorMetrics::CIELab
        options[:metric].distance(self, other)
      end

      def initialize_copy(other)
        r = super
        other.instance_variable_set :@values, @values.dup
        r
      end

      def gradient_to(other, options = {})
        options[:steps] ||= 16
        steps = options[:steps].to_i
        steps < 2 and raise ArgumentError, 'at least 2 steps are required'
        changes = other.values.zip(@values).map { |x, y| x - y }
        current = self
        gradient = [ current.dup ]
        s = steps - 1
        while s > 1
          current = current.dup
          gradient << current
          3.times do |i|
            current.values[i] += changes[i] / (steps - 1)
          end
          s -= 1
        end
        gradient << other
      end

      def method_missing(name, *args, &block)
        if Term::ANSIColor::HSLTriple.method_defined?(name)
          to_hsl_triple.send(name, *args, &block)
        else
          super
        end
      end
    end
  end
end
