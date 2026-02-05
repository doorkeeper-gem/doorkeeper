# frozen_string_literal: false

require 'test_helper'
require 'tempfile'

module Tins
  class TinsLinesFileTest < Test::Unit::TestCase
    FILE = <<EOT
def foo
end

def bar
end

def baz
end
EOT

    def test_instantiation
      write_file do |file|
        file.write FILE
        file.rewind
        assert_kind_of Tins::LinesFile, lf = Tins::LinesFile.for_file(file)
        assert_equal [ "def foo\n", 1 ], [ lf.line, lf.line.line_number ]
        assert_kind_of Tins::LinesFile, lf = Tins::LinesFile.for_filename(file.path)
        assert_equal [ "def foo\n", 1 ], [ lf.line, lf.line.line_number ]
        file.rewind
        assert_kind_of Tins::LinesFile, lf = Tins::LinesFile.for_lines(file.readlines)
        assert_equal [ "def foo\n", 1 ], [ lf.line, lf.line.line_number ]
      end
    end

    def test_match
      write_file do |file|
        file.write FILE
        file.rewind
        lf = Tins::LinesFile.for_file(file)
        assert_equal "def foo\n", lf.line
        assert_equal 1, lf.line.line_number
        assert_equal %w[foo], lf.match_forward(/def (\S+)/)
        assert_equal "def foo\n", lf.line
        assert_equal %w[foo], lf.match_forward(/def (\S+)/, true)
        assert_equal 2, lf.line.line_number
        assert_equal "end\n", lf.line
        assert_equal %w[bar], lf.match_forward(/def (\S+)/, true)
        assert_equal 5, lf.line.line_number
        assert_equal %w[baz], lf.match_forward(/def (\S+)/, true)
        assert_nil   lf.match_forward(/def (\S+)/, true)
        assert_equal "end\n", lf.line
        assert_equal 8, lf.line.line_number
        assert_equal %w[baz], lf.match_backward(/def (\S+)/)
        assert_equal "def baz\n", lf.line
        assert_equal 7, lf.line.line_number
        assert_equal %w[baz], lf.match_backward(/def (\S+)/, true)
        assert_equal "\n", lf.line
        assert_equal 6, lf.line.line_number
        assert_equal %w[bar], lf.match_backward(/def (\S+)/, true)
        assert_equal %w[foo], lf.match_backward(/def (\S+)/, true)
        assert_equal nil, lf.match_backward(/nada/, true)
      end
    end

    def test_empty_and_not
      lf = Tins::LinesFile.for_lines []
      assert_equal true, lf.empty?
      assert_equal 0, lf.last_line_number
      assert_equal [], lf.to_a
      lf = Tins::LinesFile.for_lines [ "foo\n" ]
      assert_equal false, lf.empty?
      assert_equal 1, lf.last_line_number
      assert_equal [ "foo\n" ], lf.to_a
      assert_equal [ "foo\n", 1 ], [ lf.line, lf.line.line_number ]
    end

    private

    def write_file
      File.open(File.join(Dir.tmpdir, "temp.#$$"), 'wb+') do |file|
        yield file
      end
    end
  end
end
