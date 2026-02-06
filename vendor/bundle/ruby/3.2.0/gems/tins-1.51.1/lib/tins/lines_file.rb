module Tins
  # Tins::LinesFile provides enhanced file line processing capabilities.
  #
  # This class wraps file content in a way that allows for rich line-level
  # operations, including tracking line numbers, filenames, and providing
  # convenient navigation and matching methods. It's particularly useful for
  # log processing, configuration files, or any scenario where you need to
  # work with structured text data while maintaining context about line
  # positions.
  #
  # @example Basic usage
  #   lines_file = Tins::LinesFile.for_filename('example.txt')
  #   lines_file.each do |line|
  #     puts line.file_linenumber  # => "example.txt:1"
  #     puts line.line_number      # => 1
  #   end
  #
  # @example Line navigation and matching
  #   lines_file = Tins::LinesFile.for_filename('example.txt')
  #   lines_file.next!           # Move to next line
  #   lines_file.match_forward(/pattern/)  # Match forward from current position
  class LinesFile
    # Extension module that adds line metadata to individual lines.
    #
    # This module is automatically mixed into each line when a LinesFile is created,
    # providing access to line number and filename information directly from the line objects.
    module LineExtension
      # @return [Integer] The line number (1-based) of this line
      attr_reader :line_number

      # @return [String] The filename associated with this line's source
      def filename
        lines_file.filename.dup
      end
    end

    # Create a LinesFile instance from a filename.
    #
    # @param filename [String] Path to the file to read
    # @param line_number [Integer] Starting line number (default: 1)
    # @return [LinesFile] A new LinesFile instance
    def self.for_filename(filename, line_number = nil)
      obj = new(File.readlines(filename), line_number)
      obj.filename = filename
      obj
    end

    # Create a LinesFile instance from an already opened file.
    #
    # @param file [File] An open File object to read from
    # @param line_number [Integer] Starting line number (default: 1)
    # @return [LinesFile] A new LinesFile instance
    def self.for_file(file, line_number = nil)
      obj = new(file.readlines, line_number)
      obj.filename = file.path
      obj
    end

    # Create a LinesFile instance from an array of lines.
    #
    # @param lines [Array<String>] Array of line strings
    # @param line_number [Integer] Starting line number (default: 1)
    # @return [LinesFile] A new LinesFile instance
    def self.for_lines(lines, line_number = nil)
      new(lines, line_number)
    end

    # Initialize a LinesFile with lines and optional starting line number.
    #
    # @param lines [Array<String>] Array of line strings to process
    # @param line_number [Integer] Starting line number (default: 1)
    def initialize(lines, line_number = nil)
      @lines = lines
      @lines.each_with_index do |line, i|
        line.extend LineExtension
        line.instance_variable_set :@line_number, i + 1
        line.instance_variable_set :@lines_file, self
      end
      instance_variable_set :@line_number, line_number || (@lines.empty? ? 0 : 1)
    end

    # @return [String] The filename associated with this LinesFile
    attr_accessor :filename

    # @return [Integer] The current line number (1-based)
    attr_reader :line_number

    # Reset the current line number to the beginning.
    #
    # @return [LinesFile] Returns self for chaining
    def rewind
      self.line_number = 1
      self
    end

    # Move to the next line.
    #
    # @return [LinesFile, nil] Returns self if successful, nil if at end of file
    def next!
      old = line_number
      self.line_number += 1
      line_number > old ? self : nil
    end

    # Move to the previous line.
    #
    # @return [LinesFile, nil] Returns self if successful, nil if at beginning
    def previous!
      old = line_number
      self.line_number -= 1
      line_number < old ? self : nil
    end

    # Set the current line number.
    #
    # @param number [Integer] The new line number to set
    # @return [void]
    def line_number=(number)
      number = number.to_i
      if number > 0 && number <= last_line_number
        @line_number = number
      end
    end

    # @return [Integer] The total number of lines in this file
    def last_line_number
      @lines.size
    end

    # @return [Boolean] True if the file has no lines
    def empty?
      @lines.empty?
    end

    # Iterate through all lines, setting the current line number for each.
    #
    # @yield [line] Each line in the file
    # @yieldparam line [String] The current line object with line metadata
    # @return [LinesFile] Returns self for chaining
    def each(&block)
      empty? and return self
      old_line_number = line_number
      1.upto(last_line_number) do |number|
        self.line_number = number
        block.call(line)
      end
      self
    ensure
      self.line_number = old_line_number
    end
    include Enumerable

    # @return [String, nil] The current line content or nil if out of bounds
    def line
      index = line_number - 1
      @lines[index] if index >= 0
    end

    # @return [String] Formatted filename and line number (e.g., "file.txt:5")
    def file_linenumber
      "#{filename}:#{line_number}"
    end

    # Match a regular expression backward from current position.
    #
    # @param regexp [Regexp] The regular expression to match
    # @param previous_after_match [Boolean] Whether to move back one line after match
    # @return [Array<String>, nil] Captured groups or nil if no match
    def match_backward(regexp, previous_after_match = false)
      begin
        if line =~ regexp
          previous_after_match and previous!
          return $~.captures
        end
      end while previous!
    end

    # Match a regular expression forward from current position.
    #
    # @param regexp [Regexp] The regular expression to match
    # @param next_after_match [Boolean] Whether to move forward one line after match
    # @return [Array<String>, nil] Captured groups or nil if no match
    def match_forward(regexp, next_after_match = false)
      begin
        if line =~ regexp
          next_after_match and next!
          return $~.captures
        end
      end while next!
    end

    # @return [String] String representation including line number and content
    def to_s
      "#{line_number} #{line.chomp}"
    end

    # @return [String] Detailed inspection string
    def inspect
      "#<#{self.class}: #{to_s.inspect}>"
    end
  end
end
