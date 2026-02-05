require 'test_helper'

OldString = String.dup

class String
  include Term::ANSIColor
end

class Color
  extend Term::ANSIColor
end

class StringLike
  def initialize(string)
    @string = string
  end

  def to_str
    @string
  end
end

class ANSIColorTest < Test::Unit::TestCase
  include Term::ANSIColor

  def setup
    @string = "red"
    @string_red = "\e[31mred\e[0m"
    @string_red_on_green = "\e[42m\e[31mred\e[0m\e[0m"
    @string_like = StringLike.new(@string)
    @string_like_red = StringLike.new(@string_red)
  end

  attr_reader :string, :string_red, :string_red_on_green, :string_like, :string_like_red

  def test_red
    assert_equal string_red, string.red
    assert_equal string_red, Color.red(string)
    assert_equal string_red, Color.red { string }
    assert_equal string_red, Term::ANSIColor.red { string }
    assert_equal string_red, red { string }
  end

  def test_red_on_green
    assert_equal string_red_on_green, string.red.on_green
    assert_equal string_red_on_green, Color.on_green(Color.red(string))
    assert_equal string_red_on_green, Color.on_green { Color.red { string } }
    assert_equal string_red_on_green,
      Term::ANSIColor.on_green { Term::ANSIColor.red { string } }
    assert_equal string_red_on_green, on_green { red { string } }
  end

  def test_color
    assert_equal "\e[38;5;128mfoo\e[0m", Color.color(:color128, "foo")
    assert_equal "\e[38;5;128mfoo\e[0m", "foo".color(:color128)
    assert_equal "\e[38;5;128mfoo\e[0m", color(:color128, "foo")
    assert_equal "\e[38;5;128mfoo\e[0m", Color.color(:color128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", "foo".color(:color128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", color(:color128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", color(:color128) + "foo" + color(:reset)
    assert_equal "\e[38;5;128mfoo\e[0m", Color.color(128, "foo")
    assert_equal "\e[38;5;128mfoo\e[0m", "foo".color(128)
    assert_equal "\e[38;5;128mfoo\e[0m", color(128, "foo")
    assert_equal "\e[38;5;128mfoo\e[0m", Color.color(128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", "foo".color(128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", color(128) { "foo" }
    assert_equal "\e[38;5;128mfoo\e[0m", color(128) + "foo" + color(:reset)
  end

  def test_on_color
    assert_equal "\e[48;5;128mfoo\e[0m", Color.on_color(:color128, "foo")
    assert_equal "\e[48;5;128mfoo\e[0m", "foo".on_color(:color128)
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(:color128, "foo")
    assert_equal "\e[48;5;128mfoo\e[0m", Color.on_color(:color128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", "foo".on_color(:color128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(:color128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(:color128) + "foo" + color(:reset)
    assert_equal "\e[48;5;128mfoo\e[0m", Color.on_color(128, "foo")
    assert_equal "\e[48;5;128mfoo\e[0m", "foo".on_color(128)
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(128, "foo")
    assert_equal "\e[48;5;128mfoo\e[0m", Color.on_color(128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", "foo".on_color(128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(128) { "foo" }
    assert_equal "\e[48;5;128mfoo\e[0m", on_color(128) + "foo" + color(:reset)
  end

  def test_uncolor
    assert_equal string, string_red.uncolor
    assert_equal string, Color.uncolor(string_red)
    assert_equal string, Color.uncolor(string_like_red)
    assert_equal string, Color.uncolor { string_red }
    assert_equal string, Color.uncolor { string_like_red }
    assert_equal string, Term::ANSIColor.uncolor { string_red }
    assert_equal string, Term::ANSIColor.uncolor { string_like_red }
    assert_equal string, uncolor { string }
    assert_equal string, uncolor { string_like_red }
    assert_equal "", uncolor(Object.new)
    for index in 0..255
      assert_equal "foo", Color.uncolor(Color.color("color#{index}", "foo"))
      assert_equal "foo", Color.uncolor(Color.on_color("color#{index}", "foo"))
    end
  end

  def test_attributes
    foo = 'foo'
    attributes = %i[
      clear reset bold dark faint italic underline underscore
      blink rapid_blink reverse negative concealed conceal strikethrough black
      red green yellow blue magenta cyan white on_black on_red on_green on_yellow
      on_blue on_magenta on_cyan on_white intense_black bright_black intense_red
      bright_red intense_green bright_green intense_yellow bright_yellow
      intense_blue bright_blue intense_magenta bright_magenta intense_cyan
      bright_cyan intense_white bright_white on_intense_black on_bright_black
      on_intense_red on_bright_red on_intense_green on_bright_green
      on_intense_yellow on_bright_yellow on_intense_blue on_bright_blue
      on_intense_magenta on_bright_magenta on_intense_cyan on_bright_cyan
      on_intense_white on_bright_white
    ]
    for a in attributes
      # skip :clear and :reverse b/c Ruby implements them on string
      if a != :clear && a != :reverse
        refute_equal foo, foo_colored = foo.__send__(a)
        assert_equal foo, foo_colored.uncolor
      end
      refute_equal foo, foo_colored = Color.__send__(a, foo)
      assert_equal foo, Color.uncolor(foo_colored)
      refute_equal foo, foo_colored = Color.__send__(a) { foo }
      assert_equal foo, Color.uncolor { foo_colored }
      refute_equal foo, foo_colored = Term::ANSIColor.__send__(a) { foo }
      assert_equal foo, Term::ANSIColor.uncolor { foo_colored }
      refute_equal foo, foo_colored = __send__(a) { foo }
      assert_equal foo, uncolor { foo_colored }
    end
    assert_equal Term::ANSIColor.attributes, 'foo'.attributes
  end

  def test_underline_invalid_type
    assert_raises(ArgumentError) { Term::ANSIColor.underline(type: :nix) { 'foo' } }
  end

  def test_underline_invalid_color
    assert_raises(ArgumentError) { Term::ANSIColor.underline(color: :nix) { 'foo' } }
  end

  def test_underline
    foo = 'foo'
    assert_equal "\e[4mfoo\e[0m", Term::ANSIColor.underline { foo }
    assert_equal "\e[4m\e[58;2;255;135;95mfoo\e[0m", Term::ANSIColor.underline(color: '#ff8040') { foo }
  end

  def test_underline_double
    foo = 'foo'
    assert_equal "\e[4:2mfoo\e[0m", Term::ANSIColor.underline(type: :double) { foo }
    assert_equal "\e[4:2m\e[58;2;255;135;95mfoo\e[0m", Term::ANSIColor.underline(type: :double, color: '#ff8040') { foo }
  end

  def test_underline_curly
    foo = 'foo'
    assert_equal "\e[4:3mfoo\e[0m", Term::ANSIColor.underline(type: :curly) { foo }
    assert_equal "\e[4:3m\e[58;2;255;135;95mfoo\e[0m", Term::ANSIColor.underline(type: :curly, color: '#ff8040') { foo }
  end

  def test_underline_dotted
    foo = 'foo'
    assert_equal "\e[4:4mfoo\e[0m", Term::ANSIColor.underline(type: :dotted) { foo }
    assert_equal "\e[4:4m\e[58;2;255;135;95mfoo\e[0m", Term::ANSIColor.underline(type: :dotted, color: '#ff8040') { foo }
  end

  def test_underline_dashed
    foo = 'foo'
    assert_equal "\e[4:5mfoo\e[0m", Term::ANSIColor.underline(type: :dashed) { foo }
    assert_equal "\e[4:5m\e[58;2;255;135;95mfoo\e[0m", Term::ANSIColor.underline(type: :dashed, color: '#ff8040') { foo }
  end

  def test_move_to
    string_23_23 = "\e[23;23Hred"
    assert_equal string_23_23, string.move_to(23, 23)
    assert_equal string_23_23, Color.move_to(23, 23, string)
    assert_equal string_23_23, Color.move_to(23, 23) { string }
    assert_equal string_23_23, Term::ANSIColor.move_to(23, 23) { string }
    assert_equal string_23_23, move_to(23, 23) { string }
  end

  def test_return_to_position
    string_return = "\e[sred\e[u"
    assert_equal string_return, string.return_to_position
    assert_equal string_return, Color.return_to_position(string)
    assert_equal string_return, Color.return_to_position { string }
    assert_equal string_return, Term::ANSIColor.return_to_position { string }
    assert_equal string_return, return_to_position { string }
  end

  def test_coloring_string_like
    assert_equal "\e[31mred\e[0m", red(string_like)
  end

  def test_frozen
    string = 'foo'.dup
    red = string.red
    string.extend(Term::ANSIColor).freeze
    assert string.frozen?
    assert_equal red, string.red
  end

  def test_extending
    string = OldString.new('new')
    assert_equal false, Term::ANSIColor === string
    string = Color.red(string)
    assert_kind_of Term::ANSIColor, 'new'
  end

  def test_coloring
    assert Term::ANSIColor.coloring?
    Term::ANSIColor.coloring = false
    assert_false Term::ANSIColor.coloring?
  ensure
    Term::ANSIColor.coloring = true
  end

  def test_true_coloring
    assert_false Term::ANSIColor.true_coloring?
    Term::ANSIColor.true_coloring = true
    assert Term::ANSIColor.true_coloring?
  ensure
    Term::ANSIColor.true_coloring = false
  end
end
