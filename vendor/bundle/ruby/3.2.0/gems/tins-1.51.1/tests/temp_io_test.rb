# encoding: utf-8

require 'test_helper'
require 'tins/xt/temp_io'

module Tins
  class TempIOTest < Test::Unit::TestCase
    def test_with_string
      returned = temp_io(content: 'foo') { |io|
        assert_equal 'foo', io.read
        :done
      }
      assert_equal returned, :done
    end

    def test_with_suffixed_name
      returned = temp_io(content: 'foo', name: 'foo.csv') { |io|
        assert_true io.path.end_with?('foo.csv')
        :done
      }
      assert_equal returned, :done
    end

    def test_with_proc
      returned = temp_io(content: -> { 'foo' }) { |io|
        assert_equal 'foo', io.read
        :done
      }
      assert_equal returned, :done
    end

    def test_with_proc_and_io_arg
      returned = temp_io(content: -> io { io << 'foo' }) { |io|
        assert_equal 'foo', io.read
        :done
      }
      assert_equal returned, :done
    end

    def test_as_enum
      enum = Tins::TempIO::Enum.new(chunk_size: 5, filename: 'foo') { |file|
        assert_kind_of File, file
        file << "hello" << "world"
      }
      assert_equal 'foo', enum.filename
      assert_equal "hello", enum.next
      assert_equal "world", enum.next
      assert_raise(StopIteration) { enum.next }
    end
  end
end
