require 'test_helper'

class HyperlinkTest < Test::Unit::TestCase
  include Term::ANSIColor

  def setup
    @link = 'https://foo.example.com'
  end

  def test_hyperlink_switch_on
    assert_equal(
      "\e]8;;#@link\e\\",
      hyperlink(@link)
    )
  end

  def test_hyperlink_switch_off
    assert_equal(
      "\e]8;;\e\\",
      hyperlink(nil)
    )
  end

  def test_hyperlink_as_link
    assert_equal(
      hyperlink(@link, as_link: true),
      "\e]8;;#@link\e\\#@link\e]8;;\e\\",
    )
  end

  def test_hyperlink_two_args
    assert_equal(
      "\e]8;;#@link\e\\foo\e]8;;\e\\",
      hyperlink(@link, 'foo')
    )
  end

  def test_hyperlink_two_args_with_id
    assert_equal(
      "\e]8;id=666;#@link\e\\foo\e]8;;\e\\",
      hyperlink(@link, 'foo', id: 666)
    )
  end

  def test_hyperlink_block_arg
    assert_raises(ArgumentError) { hyperlink(@link, 'bar') { 'baz' } }
    assert_equal(
      "\e]8;;#@link\e\\foo\e]8;;\e\\",
      hyperlink(@link) { 'foo' }
    )
  end

  def test_with_stringy_self
    string = 'foo'.dup
    string.extend Term::ANSIColor
    assert_equal "\e]8;;#@link\e\\foo\e]8;;\e\\", string.hyperlink(@link)
  end
end
