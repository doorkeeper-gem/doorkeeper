module Term
  module ANSIColor
    class HSLTriple
      def self.from_rgb_triple(rgb)
        ps = [ rgb.red / 255.0, rgb.green / 255.0, rgb.blue / 255.0 ]
        p_min = ps.min
        p_max = ps.max
        p_red, p_green, p_blue = ps

        diff = p_max - p_min
        l = (p_max + p_min) / 2

        if diff.zero?
          h = s = 0.0
        else
          if l < 0.5
            s = diff / (p_max + p_min)
          else
            s = diff / (2 - p_max - p_min)
          end

          diff_r = ( ( ( p_max - p_red ) / 6 )   + ( diff / 2 ) ) / diff
          diff_g = ( ( ( p_max - p_green ) / 6 ) + ( diff / 2 ) ) / diff
          diff_b = ( ( ( p_max - p_blue ) / 6 )  + ( diff / 2 ) ) / diff

          h = case p_max
              when p_red
                diff_b - diff_g
              when p_green
                (1 / 3.0) + diff_r - diff_b
              when p_blue
                (2 / 3.0) + diff_g - diff_r
              end

          h < 0 and h += 1
          h > 1 and h -= 1
        end
        from_hash(
          hue:        360 * h,
          saturation: 100 * s,
          lightness:  100 * l
        )
      end

      def self.from_css(css)
        case css
        when /\A\s*hsl\(\s*([^,\s]+)\s*,\s*([^%\s]+)\s*%\s*,\s*([^%\s]+)\s*%\s*\)\z/
          new(Float($1), Float($2), Float($3))
        end
      end

      def self.from_hash(options)
        new(
          options[:hue].to_f,
          options[:saturation].to_f,
          options[:lightness].to_f
        )
      end

      def self.[](thing)
        case
        when thing.respond_to?(:to_hsl_triple) then thing.to_hsl_triple
        when thing.respond_to?(:to_hash)       then from_hash(thing.to_hash)
        when thing.respond_to?(:to_str)
          thing = thing.to_str
          from_css(thing.to_str) ||
            Term::ANSIColor::RGBTriple.from_html(thing).full?(:to_hsl_triple) ||
            Term::ANSIColor::RGBTriple.from_css(thing).full?(:to_hsl_triple)
        else raise ArgumentError, "cannot convert #{thing.inspect} into #{self}"
        end
      end

      def initialize(hue, saturation, lightness)
        @hue        = Float(hue) % 360
        @saturation = Float(saturation).clamp(0, 100)
        @lightness  = Float(lightness).clamp(0, 100)
      end

      attr_reader :hue

      attr_reader :saturation

      attr_reader :lightness

      def lighten(percentage)
        self.class.new(@hue, @saturation, @lightness + percentage)
      end

      def darken(percentage)
        self.class.new(@hue, @saturation, @lightness - percentage)
      end

      def saturate(percentage)
        self.class.new(@hue, @saturation + percentage, @lightness)
      end

      def desaturate(percentage)
        self.class.new(@hue, @saturation - percentage, @lightness)
      end

      def adjust_hue(degree)
        self.class.new(@hue + degree, @saturation, @lightness)
      end

      def grayscale
        self.class.new(@hue, 0, @lightness)
      end

      def complement
        adjust_hue(180)
      end

      def hue2rgb(x, y, h)
        h < 0 and h += 1
        h > 1 and h -= 1
        (6 * h) < 1 and return x + (y - x) * 6 * h
        (2 * h) < 1 and return y
        (3 * h) < 2 and return x + (y - x) * ( (2 / 3.0) - h ) * 6
        x
      end
      private :hue2rgb

      def to_rgb_triple
        h = @hue        / 360.0
        s = @saturation / 100.0
        l = @lightness  / 100.0

        if s.zero?
          r = 255 * l
          g = 255 * l
          b = 255 * l
        else
           if l < 0.5
             y = l * (1 + s)
           else
             y = (l + s) - (s * l)
           end

           x = 2 * l - y

           r = 255 * hue2rgb(x, y, h + (1 / 3.0))
           g = 255 * hue2rgb(x, y, h)
           b = 255 * hue2rgb(x, y, h - (1 / 3.0))
        end
        Term::ANSIColor::RGBTriple.new(r.round, g.round, b.round)
      end

      def to_hsl_triple
        self
      end

      def css
        "hsl(%s,%s%%,%s%%)" % [ @hue, @saturation, @lightness ]
      end

      def ==(other)
        to_rgb_triple == other.to_rgb_triple
      end

      def method_missing(name, *args, &block)
        if Term::ANSIColor::RGBTriple.method_defined?(name)
          to_rgb_triple.send(name, *args, &block)
        else
          super
        end
      end
    end
  end
end
