require 'test_helper'
require 'tins/xt/to'

module Tins
  class ToTest < Test::Unit::TestCase
    def test_to_removing_leading_spaces
      doc = to(<<-EOT)
        hello, world
      EOT
      assert_equal "hello, world\n", doc
    end

    def test_to_removing_leading_spaces_depending_on_first_line
      doc = to(<<-EOT)
        hello
          world,
            how are
          things?
      EOT
      assert_equal "hello\n  world,\n    how are\n  things?\n", doc
    end

    def test_to_not_removing_empty_lines
      doc = to(<<-EOT)
        hello, world

        another line
      EOT
      assert_equal "hello, world\n\nanother line\n", doc
    end
  end
end
