require 'test_helper'
require 'tins/xt'

module Tins
  if defined? ::Encoding
    class StringByteOrderMarkTest < Test::Unit::TestCase
      def test_no_bom_encoding
        assert_nil "abcdef".bom_encoding
      end

      def test_utf8_bom_encoding
        assert_equal Encoding::UTF_8, "\xef\xbb\xbf".bom_encoding
      end

      def test_utf16be_bom_encoding
        assert_equal Encoding::UTF_16BE, "\xfe\xff".bom_encoding
      end

      def test_utf16le_bom_encoding
        assert_equal Encoding::UTF_16LE, "\xff\xfe".bom_encoding
      end

      def test_utf32be_bom_encoding
        assert_equal Encoding::UTF_32BE, "\x00\x00\xff\xfe".bom_encoding
      end

      def test_utf32le_bom_encoding
        assert_equal Encoding::UTF_32LE, "\xff\xfe\x00\x00".bom_encoding
      end

      def test_utf7_bom_encoding
        assert_equal Encoding::UTF_7, "\x2b\x2f\x76\x38".bom_encoding
        assert_equal Encoding::UTF_7, "\x2b\x2f\x76\x39".bom_encoding
        assert_equal Encoding::UTF_7, "\x2b\x2f\x76\x2b".bom_encoding
        assert_equal Encoding::UTF_7, "\x2b\x2f\x76\x2f".bom_encoding
        assert_equal Encoding::UTF_7, "\x2b\x2f\x76\x38\x2d".bom_encoding
      end
    end
  end
end
