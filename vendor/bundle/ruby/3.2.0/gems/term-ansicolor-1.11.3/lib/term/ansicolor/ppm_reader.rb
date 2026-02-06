module Term
  module ANSIColor
    class PPMReader
      include Term::ANSIColor

      def initialize(io, options = {})
        @io            = io
        @options       = options
        @buffer        = ''.dup
        if options[:true_coloring]
          @color = -> pixel { on_color Attribute.true_color(pixel, @options) }
        else
          @color = -> pixel { on_color Attribute.nearest_rgb_color(pixel, @options) }
        end
      end

      def reset_io
        begin
          @io.rewind
        rescue Errno::ESPIPE
        end
        parse_header
      end

      def rows
        reset_io

        Enumerator.new do |yielder|
          @height.times do
            yielder.yield parse_row
          end
        end
      end

      def to_a
        rows.to_a
      end

      def to_s
        rows.map do |row|
          last_pixel = nil
          row.map do |pixel|
            if pixel != last_pixel
              last_pixel = pixel
              @color.(pixel) << ' '
            else
              ' '
            end
          end.join << reset << ?\n
        end.join
      end

      private

      def parse_row
        @width.times.map { parse_next_pixel }
      end

      def parse_next_pixel
        pixel = nil
        case @type
        when 3
          @buffer.empty? and @buffer << next_line
          @buffer.sub!(/(\d+)\s+(\d+)\s+(\d+)\s*/) do
            pixel = [ $1.to_i, $2.to_i, $3.to_i ]
            ''
          end
        when 6
          @buffer.size < 3 and @buffer << @io.read(8192)
          pixel = @buffer.slice!(0, 3).unpack('C3')
        end
        pixel
      end

      def parse_header
        (line = next_line) =~ /^P([36])$/ or raise "unknown type #{line.to_s.chomp.inspect}"
        @type = $1.to_i

        if next_line =~ /^(\d+)\s+(\d+)$/
          @width, @height = $1.to_i, $2.to_i
        else
          raise "missing dimensions"
        end

        unless next_line =~ /^255$/
          raise "only 255 max color images allowed"
        end
      end

      def next_line
        while line = @io.gets and line =~ /^#|^\s$/
        end
        line
      end
    end
  end
end
