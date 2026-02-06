require 'test_helper'

class HSLTripleTest < Test::Unit::TestCase
  include Term::ANSIColor

  def setup
    @pastel_green_rgb = Term::ANSIColor::RGBTriple['#85e085']
    @pastel_green_hsl = Term::ANSIColor::HSLTriple.new(120, 59.4, 70)
    @soft_red_rgb = Term::ANSIColor::RGBTriple['#e08585']
    @soft_blue_rgb = Term::ANSIColor::RGBTriple['#8585e0']
    @gray_rgb = Term::ANSIColor::RGBTriple['#888']
  end

  def test_hsl_cast
    assert_equal '#85e085', HSLTriple[ @pastel_green_hsl ].html
    assert_equal '#85e085', HSLTriple[ hue: 120, saturation: 59.4, lightness: 70 ].html
    assert_equal '#11ddff', HSLTriple[ '#1df' ].html
    assert_equal '#8000ff', HSLTriple[ 'rgb(128,0,255)' ].html
    assert_equal '#85e085', HSLTriple[ 'hsl(120.0,59.4%,70.0%)' ].html
    assert_raises ArgumentError do
      HSLTriple[ nil ]
    end
  end

  def test_conversion_to_hsl
    hsl = @pastel_green_rgb.to_hsl_triple
    assert_in_delta @pastel_green_hsl.hue, hsl.hue, 1e-1
    assert_in_delta @pastel_green_hsl.saturation, hsl.saturation, 1e-1
    assert_in_delta @pastel_green_hsl.lightness, hsl.lightness, 1e-1
    assert_match(/hsl\(0\.0,0\.0%,53.3333.*?%\)/, @gray_rgb.to_hsl_triple.css)
    assert_match(/hsl\(120\.0.*?,58\.82.*?%,20.0%\)/, RGBTriple[ '#155115' ].to_hsl_triple.css)
  end

  def test_conversion_to_rgb
    rgb = @pastel_green_hsl.to_rgb_triple
    assert_in_delta @pastel_green_rgb.red, rgb.red, 1e-1
    assert_in_delta @pastel_green_rgb.green, rgb.green, 1e-1
    assert_in_delta @pastel_green_rgb.blue, rgb.blue, 1e-1
    assert_equal '#155115', HSLTriple[ '#155115' ].to_rgb_triple.html
  end

  def test_lighten
    assert_in_delta 80, @pastel_green_hsl.lighten(10).lightness, 1e-3
  end

  def test_darken
    assert_in_delta 60, @pastel_green_hsl.darken(10).lightness, 1e-3
  end

  def test_saturate
    assert_in_delta 69.4, @pastel_green_hsl.saturate(10).saturation, 1e-3
  end

  def test_desaturate
    assert_in_delta 49.4, @pastel_green_hsl.desaturate(10).saturation, 1e-3
  end

  def test_adjust_hue
    assert_in_delta 130, @pastel_green_hsl.adjust_hue(10).hue, 1e-3
  end

  def test_grayscale
    assert_equal '#b3b3b3', @pastel_green_hsl.grayscale.html
  end

  def test_complement
    assert_in_delta 300, @pastel_green_hsl.complement.hue, 1e-3
    assert_in_delta 300 - 120, @soft_red_rgb.complement.hue, 1e-3
    assert_in_delta 300 - 240, @soft_blue_rgb.complement.hue, 1e-3
  end

  def test_css
    assert_equal 'hsl(120.0,59.4%,70.0%)', @pastel_green_hsl.css
    assert_equal '#85e085', HSLTriple.from_css('hsl(120.0,59.4%,70.0%)').html
  end

  def test_equality
    assert_equal @pastel_green_hsl, @pastel_green_rgb
    assert_equal @pastel_green_rgb, @pastel_green_hsl
  end

  def test_method_missing
    assert_raises(NoMethodError) { @pastel_green_hsl.foo }
  end
end
