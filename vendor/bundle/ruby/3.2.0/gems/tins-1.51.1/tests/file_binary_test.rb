require 'test_helper'
require 'tempfile'
require 'tins/xt'

module Tins
  class TinsFileBinaryTest < Test::Unit::TestCase
    def test_ascii_buffer_size
      write_file do |file|
        file.write "A" * 10 + "\x00"
        assert_equal true,  file.ascii?(buffer_size: 10)
        assert_equal true,  File.ascii?(file.path, buffer_size: 10)
        assert_equal false, file.binary?(buffer_size: 10)
        assert_equal false, File.binary?(file.path, buffer_size: 10)
      end
    end

    def test_binary
      write_file do |file|
        file.write "A" * 69 + "\x01" * 31
        assert_equal true,  file.binary?
        assert_equal true,  File.binary?(file.path)
        assert_equal false, file.ascii?
        assert_equal false, File.ascii?(file.path)
      end
    end

    def test_ascii_offset
      write_file do |file|
        file.write "\x01" * 31 + "A" * 70
        assert_equal false, file.binary?(offset: 1)
        assert_equal false, File.binary?(file.path, offset: 1)
        assert_equal true,  file.ascii?(offset: 1)
        assert_equal true,  File.ascii?(file.path, offset: 1)
      end
    end

    def test_binary_zero
      write_file do |file|
        file.write "A" * 50 + "\0"  + "A" * 49
        assert_equal true,  file.binary?
        assert_equal true,  File.binary?(file.path)
        assert_equal false, file.ascii?
        assert_equal false, File.ascii?(file.path)
      end
    end

    def test_ascii
      write_file do |file|
        file.write "A" * 100
        assert_equal false, file.binary?
        assert_equal false, File.binary?(file.path)
        assert_equal true,  file.ascii?
        assert_equal true,  File.ascii?(file.path)
      end
    end

    private

    def write_file
      File.open(File.join(Dir.tmpdir, "temp.#$$"), 'wb+') do |file|
        yield file
      end
    end
  end
end
