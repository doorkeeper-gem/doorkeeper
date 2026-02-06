require 'tins/concern'

module Tins
  # Tins::StringByteOrderMark provides methods for detecting and identifying
  # byte order marks (BOMs) in strings.
  #
  # This module contains the `bom_encoding` method which analyzes the beginning
  # of a string to determine its encoding based on the presence of BOM bytes.
  # This is particularly useful when working with text files that may have
  # different encodings and BOM markers.
  #
  # @example Detecting UTF-8 BOM
  #   "\xef\xbb\xbfhello".bom_encoding
  #   # => Encoding::UTF_8
  #
  # @example Detecting UTF-16BE BOM
  #   "\xfe\xffhello".bom_encoding
  #   # => Encoding::UTF_16BE
  #
  # @example No BOM detected
  #   "hello".bom_encoding
  #   # => nil
  module StringByteOrderMark
    # Detect the encoding of a string based on its byte order mark (BOM).
    #
    # This method examines the first 4 bytes of the string to identify
    # common Unicode BOM patterns and returns the corresponding Encoding object.
    # The method handles various Unicode encodings that use BOM markers:
    # - UTF-8 (EF BB BF)
    # - UTF-16BE (FE FF)
    # - UTF-16LE (FF FE)
    # - UTF-32BE (00 00 FF FE)
    # - UTF-32LE (FF FE 00 00)
    # - UTF-7 (2B 2F 76 followed by specific bytes)
    # - GB18030 (84 31 95 33)
    #
    # @return [Encoding, nil] The detected encoding if a BOM is found, otherwise nil
    def bom_encoding
      prefix = self[0, 4].force_encoding(Encoding::ASCII_8BIT)
      case prefix
      when /\A\xef\xbb\xbf/n                    then Encoding::UTF_8
      when /\A\x00\x00\xff\xfe/n                then Encoding::UTF_32BE
      when /\A\xff\xfe\x00\x00/n                then Encoding::UTF_32LE
      when /\A\xfe\xff/n                        then Encoding::UTF_16BE
      when /\A\xff\xfe/n                        then Encoding::UTF_16LE
      when /\A\x2b\x2f\x76[\x38-\x39\x2b\x2f]/n then Encoding::UTF_7
      when /\A\x84\x31\x95\x33/n                then Encoding::GB18030
      end
    end
  end
end
