require 'test_helper'

class RgbTripleTest < Test::Unit::TestCase
  include Term::ANSIColor

  def test_rgb_cast
    rgb = RGBTriple.new(128, 0, 255)
    assert_equal '#8000ff', RGBTriple[ rgb ].html
    assert_equal '#8000ff', RGBTriple[ [ 128, 0, 255 ] ].html
    assert_equal '#8000ff', RGBTriple[ :red => 128, :green => 0, :blue => 255 ].html
    assert_equal '#11ddff', RGBTriple[ '#1df' ].html
    assert_equal '#8000ff', RGBTriple[ 'rgb(128,0,255)' ].html
    assert_equal '#85e085', RGBTriple[ 'hsl(120.0,59.4%,70.0%)' ].html
    assert_raises ArgumentError do
      RGBTriple[ nil ]
    end
  end

  def test_rgb_to_a
    rgb = RGBTriple.new(128, 0, 255)
    assert_equal [ 128, 0, 255 ], rgb.to_a
  end

  def test_percentages
    rgb = RGBTriple.new(128, 0, 255)
    assert_in_delta 50.19, rgb.red_p, 1e-2
    assert_in_delta 0.0, rgb.green_p, 1e-2
    assert_in_delta 100.0, rgb.blue_p, 1e-2
  end

  def test_rgb_distance
    rgb1 = RGBTriple.new(128, 0, 255)
    rgb2 = RGBTriple.new(128, 200, 64)
    assert_in_delta 0.0, rgb1.distance_to(rgb1), 1e-3
    assert_in_delta 255, RGBTriple.new(0, 0, 0).distance_to(RGBTriple.new(255, 255, 255)), 1e-3
    assert_in_delta 209.935, rgb1.distance_to(rgb2), 1e-3
  end

  def test_rgb_gray
    rgb1 = RGBTriple.new(0, 0, 0)
    assert_equal false, rgb1.gray?
    rgb2 = RGBTriple.new(255, 255, 255)
    assert_equal false, rgb2.gray?
    rgb3 = RGBTriple.new(12, 23, 34)
    assert_equal false, rgb3.gray?
    rgb4 = RGBTriple.new(127, 127, 127)
    assert_equal true, rgb4.gray?
  end

  def test_gradient
    rgb1 = RGBTriple.new(0, 0, 0)
    rgb2 = RGBTriple.new(255, 255, 255)
    g0 = rgb1.gradient_to(rgb2, :steps => 2)
    assert_equal 2, g0.size
    assert_equal rgb1, g0[0]
    assert_equal rgb2, g0[1]
    g1 = rgb1.gradient_to(rgb2, :steps => 3)
    assert_equal 3, g1.size
    assert_equal rgb1, g1[0]
    assert_equal 127, g1[1].red
    assert_equal 127, g1[1].green
    assert_equal 127, g1[1].blue
    assert_equal rgb2, g1[2]
    g2 = rgb1.gradient_to(rgb2, :steps => 6)
    assert_equal 6, g2.size
    assert_equal rgb1, g2[0]
    assert_equal 51, g2[1].red
    assert_equal 51, g2[1].green
    assert_equal 51, g2[1].blue
    assert_equal 102, g2[2].red
    assert_equal 102, g2[2].green
    assert_equal 102, g2[2].blue
    assert_equal 153, g2[3].red
    assert_equal 153, g2[3].green
    assert_equal 153, g2[3].blue
    assert_equal 204, g2[4].red
    assert_equal 204, g2[4].green
    assert_equal 204, g2[4].blue
    assert_equal rgb2, g2[5]
  end

  def test_invert
    assert_equal RGBTriple.new(127, 255, 0), RGBTriple.new(128, 0, 255).invert
  end

  def test_css
    rgb = RGBTriple.new(128, 0, 255)
    assert_equal 'rgb(128,0,255)', rgb.css
    assert_equal '#8000ff', RGBTriple.from_css('rgb(128,0,255)').html
    assert_match(/rgb\(50\.19.*?%,0\.0%,100.0%\)/, rgb.css(percentage: true))
    assert_equal '#8000ff', RGBTriple.from_css('rgb(50.19607843137255%,0.0%,100.0%)').html
  end

  def test_color
    assert_equal "\e[38;5;93mfoo\e[0m", RGBTriple.new(128, 0, 255).color('foo')
  end

  def test_method_missing
    assert_raises(NoMethodError) { RGBTriple.new(0, 0, 0).foo }
  end
end
