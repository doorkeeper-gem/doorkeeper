require 'test_helper'

class RGBColorMetrics < Test::Unit::TestCase
  include Term::ANSIColor

  def setup
    @black = RGBTriple.new(0, 0, 0)
    @white = RGBTriple.new(255, 255, 255)
    @red = RGBTriple.new(255, 0, 0)
    @bright_orange = RGBTriple.new(0, 200, 128)
  end

  def test_metric_getters
    assert_raises(ArgumentError) { RGBColorMetrics.metric('Foo') }
    assert_equal RGBColorMetrics::Euclidean, RGBColorMetrics.metric('Euclidean')
    assert_equal RGBColorMetrics::Euclidean, RGBColorMetrics.metric(:Euclidean)
    assert_operator RGBColorMetrics.metrics.size, :>, 1
    assert_equal true, RGBColorMetrics.metrics.include?(:Euclidean)
    assert RGBColorMetrics.metric?(:Euclidean)
    assert_equal RGBColorMetrics::Euclidean, RGBColorMetrics.metric?(:Euclidean)
  end

  def test_euclidean
    assert_in_delta 255,     RGBColorMetrics::Euclidean.distance(@black, @red), 1e-3
    assert_in_delta 255,     RGBColorMetrics::Euclidean.distance(@red, @black), 1e-3
    assert_in_delta 360.624, RGBColorMetrics::Euclidean.distance(@white, @red), 1e-3
    assert_in_delta 360.624, RGBColorMetrics::Euclidean.distance(@red, @white), 1e-3
    assert_in_delta 441.672, RGBColorMetrics::Euclidean.distance(@white, @black), 1e-3
    assert_in_delta 441.672, RGBColorMetrics::Euclidean.distance(@black, @white), 1e-3
    assert_in_delta 237.453, RGBColorMetrics::Euclidean.distance(@black, @bright_orange), 1e-3
    assert_in_delta 237.453, RGBColorMetrics::Euclidean.distance(@bright_orange, @black), 1e-3
    assert_in_delta 290.136, RGBColorMetrics::Euclidean.distance(@white, @bright_orange), 1e-3
    assert_in_delta 290.136, RGBColorMetrics::Euclidean.distance(@bright_orange, @white), 1e-3
  end

  def test_ntsc
    assert_in_delta 139.436, RGBColorMetrics::NTSC.distance(@black, @red), 1e-3
    assert_in_delta 139.436, RGBColorMetrics::NTSC.distance(@red, @black), 1e-3
    assert_in_delta 213.500, RGBColorMetrics::NTSC.distance(@white, @red), 1e-3
    assert_in_delta 213.500, RGBColorMetrics::NTSC.distance(@red, @white), 1e-3
    assert_in_delta 255,     RGBColorMetrics::NTSC.distance(@white, @black), 1e-3
    assert_in_delta 255,     RGBColorMetrics::NTSC.distance(@black, @white), 1e-3
    assert_in_delta 159.209, RGBColorMetrics::NTSC.distance(@black, @bright_orange), 1e-3
    assert_in_delta 159.209, RGBColorMetrics::NTSC.distance(@bright_orange, @black), 1e-3
    assert_in_delta 151.844, RGBColorMetrics::NTSC.distance(@white, @bright_orange), 1e-3
    assert_in_delta 151.844, RGBColorMetrics::NTSC.distance(@bright_orange, @white), 1e-3
  end

  def test_compu_phase
    assert_in_delta 360.624, RGBColorMetrics::CompuPhase.distance(@black, @red), 1e-3
    assert_in_delta 360.624, RGBColorMetrics::CompuPhase.distance(@red, @black), 1e-3
    assert_in_delta 624.619, RGBColorMetrics::CompuPhase.distance(@white, @red), 1e-3
    assert_in_delta 624.619, RGBColorMetrics::CompuPhase.distance(@red, @white), 1e-3
    assert_in_delta 721.248, RGBColorMetrics::CompuPhase.distance(@white, @black), 1e-3
    assert_in_delta 721.248, RGBColorMetrics::CompuPhase.distance(@black, @white), 1e-3
    assert_in_delta 439.053, RGBColorMetrics::CompuPhase.distance(@black, @bright_orange), 1e-3
    assert_in_delta 439.053, RGBColorMetrics::CompuPhase.distance(@bright_orange, @black), 1e-3
    assert_in_delta 417.621, RGBColorMetrics::CompuPhase.distance(@white, @bright_orange), 1e-3
    assert_in_delta 417.621, RGBColorMetrics::CompuPhase.distance(@bright_orange, @white), 1e-3
  end

  def test_yuv
    assert_in_delta 178.308, RGBColorMetrics::YUV.distance(@black, @red), 1e-3
    assert_in_delta 178.308, RGBColorMetrics::YUV.distance(@red, @black), 1e-3
    assert_in_delta 240.954, RGBColorMetrics::YUV.distance(@white, @red), 1e-3
    assert_in_delta 240.954, RGBColorMetrics::YUV.distance(@red, @white), 1e-3
    assert_in_delta 255,     RGBColorMetrics::YUV.distance(@white, @black), 1e-3
    assert_in_delta 255,     RGBColorMetrics::YUV.distance(@black, @white), 1e-3
    assert_in_delta 175.738, RGBColorMetrics::YUV.distance(@black, @bright_orange), 1e-3
    assert_in_delta 175.738, RGBColorMetrics::YUV.distance(@bright_orange, @black), 1e-3
    assert_in_delta 169.082, RGBColorMetrics::YUV.distance(@white, @bright_orange), 1e-3
    assert_in_delta 169.082, RGBColorMetrics::YUV.distance(@bright_orange, @white), 1e-3
  end

  def test_ciexyz
    assert_in_delta 124.843, RGBColorMetrics::CIEXYZ.distance(@black, @red), 1e-3
    assert_in_delta 124.843, RGBColorMetrics::CIEXYZ.distance(@red, @black), 1e-3
    assert_in_delta 316.014, RGBColorMetrics::CIEXYZ.distance(@white, @red), 1e-3
    assert_in_delta 316.014, RGBColorMetrics::CIEXYZ.distance(@red, @white), 1e-3
    assert_in_delta 411.874, RGBColorMetrics::CIEXYZ.distance(@white, @black), 1e-3
    assert_in_delta 411.874, RGBColorMetrics::CIEXYZ.distance(@black, @white), 1e-3
    assert_in_delta 137.920, RGBColorMetrics::CIEXYZ.distance(@black, @bright_orange), 1e-3
    assert_in_delta 137.920, RGBColorMetrics::CIEXYZ.distance(@bright_orange, @black), 1e-3
    assert_in_delta 280.023, RGBColorMetrics::CIEXYZ.distance(@white, @bright_orange), 1e-3
    assert_in_delta 280.023, RGBColorMetrics::CIEXYZ.distance(@bright_orange, @white), 1e-3
  end

  def test_cielab
    assert_in_delta 174.656, RGBColorMetrics::CIELab.distance(@black, @red), 1e-3
    assert_in_delta 174.656, RGBColorMetrics::CIELab.distance(@red, @black), 1e-3
    assert_in_delta 158.587, RGBColorMetrics::CIELab.distance(@white, @red), 1e-3
    assert_in_delta 158.587, RGBColorMetrics::CIELab.distance(@red, @white), 1e-3
    assert_in_delta 255,     RGBColorMetrics::CIELab.distance(@white, @black), 1e-3
    assert_in_delta 255,     RGBColorMetrics::CIELab.distance(@black, @white), 1e-3
    assert_in_delta 191.927, RGBColorMetrics::CIELab.distance(@black, @bright_orange), 1e-3
    assert_in_delta 191.927, RGBColorMetrics::CIELab.distance(@bright_orange, @black), 1e-3
    assert_in_delta 95.084, RGBColorMetrics::CIELab.distance(@white, @bright_orange), 1e-3
    assert_in_delta 95.084, RGBColorMetrics::CIELab.distance(@bright_orange, @white), 1e-3
  end
end
