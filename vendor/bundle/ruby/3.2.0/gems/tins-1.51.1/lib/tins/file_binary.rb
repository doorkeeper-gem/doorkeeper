module Tins
  # A module for detecting and analyzing binary files based on content patterns
  #
  # This module provides functionality to determine whether a file contains
  # binary data by examining its content against various thresholds for
  # null bytes and high-order bits. It's useful for identifying files that
  # are not plain text, such as images, executables, or other binary formats.
  #
  # The detection is performed by scanning a specified portion of the file
  # and calculating the percentage of bytes that match binary criteria.
  module FileBinary
    # Constants used for binary detection logic
    module Constants
      # Seek constant for absolute positioning
      SEEK_SET = ::File::SEEK_SET

      # Regular expression matching null bytes (zero bytes)
      ZERO_RE   = +"\x00"

      # Regular expression matching binary bytes (high-order bits set)
      BINARY_RE = +"\x01-\x1f\x7f-\xff"

      # Ensure proper encoding for Ruby 1.9+
      if defined?(::Encoding)
        ZERO_RE.force_encoding(Encoding::ASCII_8BIT)
        BINARY_RE.force_encoding(Encoding::ASCII_8BIT)
      end
    end

    # Default configuration options for binary detection
    class << self
      # Accessor for default options hash
      attr_accessor :default_options
    end

    # Configuration hash with sensible defaults for binary file detection
    self.default_options = {
      # Starting offset for scanning file content
      offset:            0,

      # Buffer size in bytes for reading file content
      buffer_size:       2 ** 13,  # 8KB

      # Percentage threshold for binary bytes (high-order bits set)
      percentage_binary: 30.0,

      # Percentage threshold for null bytes (zeros)
      percentage_zeros:  0.0,
    }

    # Determines if a file is considered binary based on content analysis
    #
    # A file is classified as binary if either:
    # 1. The percentage of null bytes exceeds the configured threshold
    # 2. The percentage of binary bytes (bytes with high-order bit set) exceeds
    #    the configured threshold
    #
    # @param options [Hash] Configuration options for binary detection
    # @option options [Integer] :offset (0) Starting position in file to begin analysis
    # @option options [Integer] :buffer_size (8192) Number of bytes to read for analysis
    # @option options [Float] :percentage_binary (30.0) Binary byte threshold percentage
    # @option options [Float] :percentage_zeros (0.0) Null byte threshold percentage
    #
    # @return [Boolean, nil] true if binary, false if not binary, nil if file is empty
    #
    # @example Basic usage
    #   FileBinary.binary?('large_binary_file.dat')  # => true
    #
    # @example Custom thresholds
    #   FileBinary.binary?('file.txt', percentage_binary: 10.0)  # => false
    #
    # @example With offset and buffer size
    #   FileBinary.binary?('file.log', offset: 1024, buffer_size: 4096)  # => true
    def binary?(options = {})
      options = FileBinary.default_options.merge(options)
      old_pos = tell
      seek options[:offset], Constants::SEEK_SET
      data = read options[:buffer_size]
      !data or data.empty? and return nil
      data_size = data.size
      data.count(Constants::ZERO_RE).to_f / data_size >
        options[:percentage_zeros] / 100.0 and return true
      data.count(Constants::BINARY_RE).to_f / data_size >
        options[:percentage_binary] / 100.0
    ensure
      old_pos and seek old_pos, Constants::SEEK_SET
    end

    # Returns the logical opposite of binary? - true if file is not binary (ASCII/text)
    #
    # @param options [Hash] Configuration options for ASCII detection
    # @option options [Integer] :offset (0) Starting position in file to begin analysis
    # @option options [Integer] :buffer_size (8192) Number of bytes to read for analysis
    # @option options [Float] :percentage_binary (30.0) Binary byte threshold percentage
    # @option options [Float] :percentage_zeros (0.0) Null byte threshold percentage
    #
    # @return [Boolean, nil] true if ASCII/text, false if binary, nil if file is empty
    #
    # @example Basic usage
    #   FileBinary.ascii?('script.rb')  # => true
    #
    # @example With custom options
    #   FileBinary.ascii?('data.bin', percentage_zeros: 5.0)  # => false
    def ascii?(options = {})
      case binary?(options)
      when true   then false
      when false  then true
      end
    end

    # Module inclusion hook that extends the including class with ClassMethods
    #
    # @param modul [Module] The module that is including FileBinary
    def self.included(modul)
      modul.instance_eval do
        extend ClassMethods
      end
      super
    end

    # Class methods that provide file-level binary detection capabilities
    #
    # These methods allow binary detection without manually opening files
    module ClassMethods
      # Determines if a file is considered binary by name
      #
      # @param name [String] Path to the file to analyze
      # @param options [Hash] Configuration options for binary detection
      # @option options [Integer] :offset (0) Starting position in file to begin analysis
      # @option options [Integer] :buffer_size (8192) Number of bytes to read for analysis
      # @option options [Float] :percentage_binary (30.0) Binary byte threshold percentage
      # @option options [Float] :percentage_zeros (0.0) Null byte threshold percentage
      #
      # @return [Boolean, nil] true if binary, false if not binary, nil if file is empty
      #
      # @example Basic usage
      #   FileBinary.binary?('config.json')  # => false
      #
      # @example With custom options
      #   FileBinary.binary?('data.dat', percentage_binary: 25.0)  # => true
      def binary?(name, options = {})
        open(name, 'rb') { |f| f.binary?(options) }
      end

      # Determines if a file is considered ASCII/text by name
      #
      # @param name [String] Path to the file to analyze
      # @param options [Hash] Configuration options for ASCII detection
      # @option options [Integer] :offset (0) Starting position in file to begin analysis
      # @option options [Integer] :buffer_size (8192) Number of bytes to read for analysis
      # @option options [Float] :percentage_binary (30.0) Binary byte threshold percentage
      # @option options [Float] :percentage_zeros (0.0) Null byte threshold percentage
      #
      # @return [Boolean, nil] true if ASCII/text, false if binary, nil if file is empty
      #
      # @example Basic usage
      #   FileBinary.ascii?('readme.md')  # => true
      #
      # @example With custom options
      #   FileBinary.ascii?('binary_file.dat', percentage_zeros: 10.0)  # => false
      def ascii?(name, options = {})
        open(name, 'rb') { |f| f.ascii?(options) }
      end
    end
  end
end
