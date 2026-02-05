module Term
  module ANSIColor
    module RGBColorMetricsHelpers
      module WeightedEuclideanDistance
        def weighted_euclidean_distance_to(other, weights = [ 1.0 ] * values.size)
          sum = 0.0
          values.zip(other.values, weights) do |s, o, w|
            sum += w * (s - o) ** 2
          end
          Math.sqrt(sum)
        end
      end

      module NormalizeRGBTriple
        private

        def normalize(v)
          v /= 255.0
          if v <= 0.04045
            v / 12
          else
            ( (v + 0.055) / 1.055 ) ** 2.4
          end
        end

        def normalize_rgb_triple(rgb_triple)
          [
            normalize(rgb_triple.red),
            normalize(rgb_triple.green),
            normalize(rgb_triple.blue),
          ]
        end
      end
    end

    module RGBColorMetrics
      def self.metric(name)
        metric?(name) or raise ArgumentError, "unknown metric #{name.inspect}"
      end

      def self.metric?(name)
        if const_defined?(name)
          const_get name
        end
      end

      def self.metrics
        constants.map(&:to_sym)
      end

      # Implements color distance how the old greeks and most donkeys would…
      module Euclidean
        def self.distance(rgb1, rgb2)
          rgb1.weighted_euclidean_distance_to rgb2
        end
      end

      # Implements color distance the best way everybody knows…
      module NTSC
        def self.distance(rgb1, rgb2)
          rgb1.weighted_euclidean_distance_to rgb2, [ 0.299, 0.587, 0.114 ]
        end
      end

      # Implements color distance as given in:
      #   http://www.compuphase.com/cmetric.htm
      module CompuPhase
        def self.distance(rgb1, rgb2)
          rmean = (rgb1.red + rgb2.red) / 2
          rgb1.weighted_euclidean_distance_to rgb2,
              [ 2 + (rmean >> 8), 4, 2 + ((255 - rmean) >> 8) ]
        end
      end

      module YUV
        class YUVTriple < Struct.new(:y, :u, :v)
          include RGBColorMetricsHelpers::WeightedEuclideanDistance

          def self.from_rgb_triple(rgb_triple)
            r, g, b = rgb_triple.red, rgb_triple.green, rgb_triple.blue
            y = (0.299 * r + 0.587 * g + 0.114 * b).round
            u = ((b - y) * 0.492).round
            v = ((r - y) * 0.877).round
            new(y, u, v)
          end
        end

        def self.distance(rgb1, rgb2)
          yuv1 = YUVTriple.from_rgb_triple(rgb1)
          yuv2 = YUVTriple.from_rgb_triple(rgb2)
          yuv1.weighted_euclidean_distance_to yuv2
        end
      end

      module CIEXYZ
        class CIEXYZTriple < Struct.new(:x, :y, :z)
          include RGBColorMetricsHelpers::WeightedEuclideanDistance
          extend RGBColorMetricsHelpers::NormalizeRGBTriple

          def self.from_rgb_triple(rgb_triple)
            r, g, b = normalize_rgb_triple rgb_triple

            x =  0.436052025 * r + 0.385081593 * g + 0.143087414 * b
            y =  0.222491598 * r + 0.71688606  * g + 0.060621486 * b
            z =  0.013929122 * r + 0.097097002 * g + 0.71418547  * b

            x *= 255
            y *= 255
            z *= 255

            new(x.round, y.round, z.round)
          end
        end

        def self.distance(rgb1, rgb2)
          xyz1 = CIEXYZTriple.from_rgb_triple(rgb1)
          xyz2 = CIEXYZTriple.from_rgb_triple(rgb2)
          xyz1.weighted_euclidean_distance_to xyz2
        end
      end

      module CIELab
        class CIELabTriple < Struct.new(:l, :a, :b)
          include RGBColorMetricsHelpers::WeightedEuclideanDistance
          extend RGBColorMetricsHelpers::NormalizeRGBTriple

          def self.from_rgb_triple(rgb_triple)
            r, g, b = normalize_rgb_triple rgb_triple

            x =  0.436052025 * r + 0.385081593 * g + 0.143087414 * b
            y =  0.222491598 * r + 0.71688606  * g + 0.060621486 * b
            z =  0.013929122 * r + 0.097097002 * g + 0.71418547  * b

            xr = x / 0.964221
            yr = y
            zr = z / 0.825211

            eps = 216.0 / 24389
            k = 24389.0 / 27

            fx = xr > eps ? xr ** (1.0 / 3) : (k * xr + 16) / 116
            fy = yr > eps ? yr ** (1.0 / 3) : (k * yr + 16) / 116
            fz = zr > eps ? zr ** (1.0 / 3) : (k * zr + 16) / 116

            l = 2.55 * ((116 * fy) - 16)
            a = 500 * (fx - fy)
            b = 200 * (fy - fz)

            new(l.round, a.round, b.round)
          end
        end

        def self.distance(rgb1, rgb2)
          lab1 = CIELabTriple.from_rgb_triple(rgb1)
          lab2 = CIELabTriple.from_rgb_triple(rgb2)
          lab1.weighted_euclidean_distance_to lab2
        end
      end
    end
  end
end
