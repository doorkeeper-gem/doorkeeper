require 'test_helper'

class AttributeTest < Test::Unit::TestCase
  include Term::ANSIColor

  def test_cast
    color = Attribute.get(:color123)
    on_color = Attribute.get(:on_color123)
    assert_equal color, Attribute[color]
    assert_equal color, Attribute[:color123]
    assert_equal color, Attribute[123]
    assert_equal color, Attribute['123']
    assert_equal color, Attribute['#87ffff']
    assert_equal color, Attribute[ [ 0x87, 0xff, 0xff ] ]
    assert_equal on_color, Attribute['on_123']
    assert_equal on_color, Attribute['on_#87ffff']
  end

  def test_gray
    a1 = Attribute[ [ 0, 0, 0 ] ]
    assert_equal false, a1.gray?
    a2 = Attribute[ [ 255, 255, 255 ] ]
    assert_equal false, a2.gray?
    a3 = Attribute[ [ 00, 0x7f, 0xff ] ]
    assert_equal false, a3.gray?
    a4 = Attribute[ [ 0x7f, 0x7f, 0x7f ] ]
    assert_equal true, a4.gray?
  end

  def test_distance_to
    color = Attribute.nearest_rgb_color('#0f0')
    assert_in_delta 250.954, Attribute.get(:color0).distance_to(color), 1e-3
    color = Attribute.nearest_rgb_color('#0f0')
    assert_in_delta 255, Attribute.get(:color0).distance_to(color,
      metric: RGBColorMetrics::Euclidean), 1e-3
    assert_equal 1 / 0.0, Attribute.get(:color0).distance_to(nil)
  end

  def test_nearest_rgb_color
    assert_equal Attribute.get(:color0).rgb, Attribute.nearest_rgb_color('#000').rgb
    assert_equal Attribute.get(:color15).rgb, Attribute.nearest_rgb_color('#ffffff').rgb
    assert_equal :color248, Attribute.nearest_rgb_color('#aaa').name
    assert_equal :color109, Attribute.nearest_rgb_color('#aaa', gray: false).name
  end

  def test_nearest_rgb_on_color
    assert_equal Attribute.get(:on_color0).rgb, Attribute.nearest_rgb_on_color('#000').rgb
    assert_equal Attribute.get(:on_color15).rgb, Attribute.nearest_rgb_on_color('#ffffff').rgb
    assert_equal :on_color248, Attribute.nearest_rgb_on_color('#aaa').name
    assert_equal :on_color109, Attribute.nearest_rgb_on_color('#aaa', gray: false).name
  end

  def test_apply
    assert_equal "\e[5m", Attribute[:blink].apply
    assert_equal "\e[5mfoo\e[0m", Attribute[:blink].apply('foo')
    assert_equal "\e[5mfoo\e[0m", Attribute[:blink].apply { 'foo' }
  end

  def test_gradient
    g0 = Attribute[:blink].gradient_to Attribute['#30ffaa']
    assert_equal [], g0
    g1 = Attribute['#30ffaa'].gradient_to(Attribute['#ff507f'], steps: 9)
    assert_equal [ :color49, :color49, :color43, :color79, :color108,
      :color247, :color138, :color168, :color204 ], g1.map(&:name)
    g2 = Attribute['#30ffaa'].gradient_to(
      Attribute['#ff507f'],
      steps: 9,
      metric: RGBColorMetrics::Euclidean
    )
    assert_equal [ :color49, :color43, :color79, :color73, :color108,
      :color247, :color138, :color168, :color204 ], g2.map(&:name)
  end

  def test_true_color
    pinkish = Attribute['#f050a0', true_coloring: true]
    assert_equal [ 240, 80, 160 ], pinkish.to_rgb_triple.to_a
    on_pinkish = Attribute['on_#f050a0', true_coloring: true]
    assert_equal [ 240, 80, 160 ], on_pinkish.to_rgb_triple.to_a
    red = Attribute['9', true_coloring: true]
    assert_equal [ 255, 0, 0 ], red.to_rgb_triple.to_a
    red = Attribute['red', true_coloring: true]
    assert_equal :red, red.name
    pinkish_pinkish = Attribute[pinkish, true_coloring: true]
    assert_equal pinkish, pinkish_pinkish
    pinkish_pinkish = Attribute[pinkish.to_rgb_triple, true_coloring: true]
    assert_equal pinkish.to_rgb_triple, pinkish_pinkish.to_rgb_triple
    pinkish_pinkish = Attribute[pinkish.to_rgb_triple.to_a, true_coloring: true]
    assert_equal pinkish.to_rgb_triple, pinkish_pinkish.to_rgb_triple
  end

  def test_true_color_gradient
    g0 = Attribute[:blink].gradient_to Attribute['#30ffaa']
    assert_equal [], g0
    g1 = Attribute['#30ffaa'].gradient_to(
      Attribute['#ff507f'],
      steps: 9,
      true_coloring: true
    )
    assert_equal %w[
      #00ffaf #1febaa #3ed7a5 #5dc3a0 #7caf9b #9b9b96 #ba8791 #d9738c #ff5f87
    ], g1.map { |c| c.rgb.html }
    g2 = Attribute['#30ffaa'].gradient_to(
      Attribute['#ff507f'],
      steps: 9,
      true_coloring: true,
      metric: RGBColorMetrics::Euclidean
    )
    assert_equal %w[
      #00ffaf #1febaa #3ed7a5 #5dc3a0 #7caf9b #9b9b96 #ba8791 #d9738c #ff5f87
    ], g2.map { |c| c.rgb.html }
  end
end
