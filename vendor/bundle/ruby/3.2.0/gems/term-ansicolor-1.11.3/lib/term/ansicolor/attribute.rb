module Term
  module ANSIColor
    class Attribute
      @__store__ = {}

      def self.set(name, code, **options)
        name = name.to_sym
        result = @__store__[name] = new(name, code, options)
        unless options[:skip_definition]
          ::Term::ANSIColor.class_eval do
            define_method(name) do |string = nil, &block|
              apply_attribute(name, string, &block)
            end
          end
        end
        result
      end

      def self.attributes(&block)
        @__store__.each_value(&block)
      end

      def self.[](name, true_coloring: false)
        true_coloring ||= Term::ANSIColor.true_coloring?
        if true_coloring
          case
          when self === name                              then name
          when Array === name                             then true_color name
          when name.respond_to?(:to_rgb_triple)           then true_color(name.to_rgb_triple.to_a)
          when name.to_s =~ /\A(on_)?(\d+)\z/             then get "#$1color#$2"
          when name.to_s =~ /\A#([0-9a-f]{3}){1,2}\z/i    then true_color name
          when name.to_s =~ /\Aon_#([0-9a-f]{3}){1,2}\z/i then on_true_color name
          else                                            get name
          end
        else
          case
          when self === name                              then name
          when Array === name                             then nearest_rgb_color name
          when name.respond_to?(:to_rgb_triple)           then nearest_rgb_color(name.to_rgb_triple.to_a)
          when name.to_s =~ /\A(on_)?(\d+)\z/             then get "#$1color#$2"
          when name.to_s =~ /\A#([0-9a-f]{3}){1,2}\z/i    then nearest_rgb_color name
          when name.to_s =~ /\Aon_#([0-9a-f]{3}){1,2}\z/i then nearest_rgb_on_color name
          else                                            get name
          end
        end
      end

      def self.get(name)
        @__store__[name.to_sym]
      end

      class << self
        def rgb_colors(options = {}, &block)
          colors = attributes.select(&:rgb_color?)
          if options.key?(:gray) && !options[:gray]
            colors = colors.reject(&:gray?)
          end
          colors.each(&block)
        end

        def rgb_foreground_colors(options = {}, &block)
          rgb_colors(options).reject(&:background?).each(&block)
        end

        def rgb_background_colors(options = {}, &block)
          rgb_colors(options).select(&:background?).each(&block)
        end
      end

      def self.named_attributes(&block)
        @named_attributes ||= attributes.reject(&:rgb_color?).each(&block)
      end

      def self.nearest_rgb_color(color, options = {})
        rgb = RGBTriple[color]
        rgb_foreground_colors(options).min_by { |c| c.distance_to(rgb, options) }
      end

      def self.nearest_rgb_on_color(color, options = {})
        rgb = RGBTriple[color]
        rgb_background_colors(options).min_by { |c| c.distance_to(rgb, options) }
      end

      def self.true_color(color, options = {})
        rgb = RGBTriple[color]
        new(:true, "", { true_color: rgb, background: false })
      end

      def self.on_true_color(color, options = {})
        rgb = RGBTriple[color]
        new(:on_true, "", { true_color: rgb, background: true })
      end

      def initialize(name, code, options = {})
        @name       = name.to_sym
        @background = !!options[:background]
        @code       = code.to_s
        @direct     = false
        @true_color = false
        if rgb = options[:true_color]
          @true_color = true
          @rgb = rgb
        elsif rgb = options[:direct]
          @direct = true
          @rgb = RGBTriple.from_html(rgb)
        elsif html = options[:html]
          @rgb = RGBTriple.from_html(html)
        elsif options.slice(:red, :green, :blue).size == 3
          @rgb = RGBTriple.from_hash(options)
        else
          @rgb = nil # prevent instance variable not initialized warnings
        end
      end

      attr_reader :name

      def code
        if true_color?
          background? ? "48;2;#{@rgb.to_a * ?;}" : "38;2;#{@rgb.to_a * ?;}"
        elsif rgb_color?
          background? ? "48;5;#{@code}" : "38;5;#{@code}"
        elsif direct?
          background? ? (@code.to_i + 10).to_s : @code
        else
          @code
        end
      end

      def apply(string = nil, &block)
        ::Term::ANSIColor.apply_attribute(self, string, &block)
      end

      def background?
        !!@background
      end

      def direct?
        !!@direct
      end

      attr_writer :background

      attr_reader :rgb

      def rgb_color?
        !!@rgb && !@true_color && !@direct
      end

      def true_color?
        !!(@rgb && @true_color)
      end

      def gray?
        rgb_color? && to_rgb_triple.gray?
      end

      def to_rgb_triple
        @rgb
      end

      def distance_to(other, options = {})
        if our_rgb = to_rgb_triple and
          other.respond_to?(:to_rgb_triple) and
          other_rgb = other.to_rgb_triple
        then
          our_rgb.distance_to(other_rgb, options)
        else
          1 / 0.0
        end
      end

      def gradient_to(other, options = {})
        if our_rgb = to_rgb_triple and
            other.respond_to?(:to_rgb_triple) and
            other_rgb = other.to_rgb_triple
          then
          true_coloring = options[:true_coloring] || Term::ANSIColor.true_coloring?
          our_rgb.gradient_to(other_rgb, options).map do |rgb_triple|
            if true_coloring
              self.class.true_color(rgb_triple, options)
            else
              self.class.nearest_rgb_color(rgb_triple, options)
            end
          end
        else
          []
        end
      end
    end
  end
end
