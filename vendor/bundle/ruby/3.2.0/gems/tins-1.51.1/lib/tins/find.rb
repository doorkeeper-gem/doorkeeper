require 'enumerator'
require 'pathname'
require 'tins/module_group'

module Tins
  # This module provides file system traversal functionality with support for
  # filtering by file type, handling of hidden files, and error management.
  #
  # The Find module implements a depth-first search algorithm that traverses
  # directory trees, yielding each path to the provided block. It handles
  # various edge cases including symbolic links, permission errors, and
  # circular references.
  #
  # @example Basic usage
  #   Tins::Find.find('/path/to/directory') do |path|
  #     puts path
  #   end
  #
  # @example Find files with specific extension
  #   Tins::Find.find('/path/to/directory', suffix: 'rb') do |path|
  #     puts path
  #   end
  #
  # @example Skip directories and files
  #   Tins::Find.find('/path/to/directory') do |path|
  #     if File.directory?(path)
  #       Tins::Find.prune  # Skip this directory and its contents
  #     else
  #       puts path
  #     end
  #   end
  module Find
    # Standard errors that are expected during file system operations
    # and will be silently handled unless raise_errors is enabled
    EXPECTED_STANDARD_ERRORS = ModuleGroup[
      Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR, Errno::ELOOP,
      Errno::ENAMETOOLONG
    ]

    # The Finder class implements the core file system traversal logic.
    # It handles path processing, error management, and directory traversal.
    class Finder
      # Extension module that adds convenience methods to Pathname objects
      # during the find operation. These methods provide access to finder
      # functionality and handle errors gracefully.
      module PathExtension
        attr_accessor :finder

        # Gets the stat information for this path, handling errors appropriately
        # @return [File::Stat, nil] File statistics or nil on error
        def finder_stat
          finder.protect_from_errors do
            finder.follow_symlinks ? File.stat(self) : File.lstat(self)
          end
        end

        # Opens the file if it's a regular file
        # @return [File, nil] File object or nil if not a file
        def file
          finder.protect_from_errors do
            File.new(self) if file?
          end
        end

        # Checks if this path represents a regular file
        # @return [Boolean] true if the path is a regular file
        def file?
          finder.protect_from_errors { s = finder_stat and s.file? }
        end

        # Checks if this path represents a directory
        # @return [Boolean] true if the path is a directory
        def directory?
          finder.protect_from_errors { s = finder_stat and s.directory? }
        end

        # Checks if this path exists
        # @return [Boolean] true if the path exists
        def exist?
          finder.protect_from_errors { File.exist?(self) }
        end

        # Gets the stat information for this path (follows symlinks)
        # @return [File::Stat, nil] File statistics or nil on error
        def stat
          finder.protect_from_errors { File.stat(self) }
        end

        # Gets the stat information for this path (does not follow symlinks)
        # @return [File::Stat, nil] File statistics or nil on error
        def lstat
          finder.protect_from_errors { File.lstat(self) }
        end

        # Creates a Pathname object from this path
        # @return [Pathname] Pathname object for this path
        def pathname
          Pathname.new(self)
        end

        # Gets the file extension without the leading dot
        # @return [String] File extension or empty string if no extension
        def suffix
          pathname.extname[1..-1] || ''
        end
      end

      # Initializes a new Finder instance with specified options
      #
      # @param opts [Hash] Configuration options
      # @option opts [Boolean] :show_hidden (true) Whether to include hidden files/directories
      # @option opts [Boolean] :raise_errors (false) Whether to raise exceptions on errors
      # @option opts [Boolean] :follow_symlinks (true) Whether to follow symbolic links
      # @option opts [Array<String, Symbol>] :suffix (nil) Filter by file extension(s)
      # @option opts [Proc] :visit (nil) Custom filter predicate
      def initialize(opts = {})
        @show_hidden     = opts.fetch(:show_hidden)     { true }
        @raise_errors    = opts.fetch(:raise_errors)    { false }
        @follow_symlinks = opts.fetch(:follow_symlinks) { true }
        if opts.key?(:visit) && opts.key?(:suffix)
          raise ArgumentError, 'either use visit or suffix argument'
        elsif opts.key?(:visit)
          @visit = opts.fetch(:visit) { -> path { true } }
        elsif opts.key?(:suffix)
          @suffix = Array(opts[:suffix])
          @visit = -> path { @suffix.nil? || @suffix.empty? || @suffix.include?(path.suffix) }
        end
      end

      # Controls whether hidden files and directories are included in the search
      # @return [Boolean]
      attr_accessor :show_hidden

      # Controls whether errors during file system operations should be raised
      # @return [Boolean]
      attr_accessor :raise_errors

      # Controls whether symbolic links should be followed during traversal
      # @return [Boolean]
      attr_accessor :follow_symlinks

      # The file suffix filter, if specified
      # @return [Array<String>] Array of allowed file extensions
      attr_accessor :suffix

      # Determines if a path should be visited based on the configured filters
      #
      # @param path [String] The path to check
      # @return [Boolean] true if the path should be visited
      def visit_path?(path)
        if !defined?(@visit) || @visit.nil?
          true
        else
          @visit.(path)
        end
      end

      # Performs a depth-first search of the specified paths
      #
      # @param paths [Array<String>] The root paths to search
      # @yield [String] Each path that matches the criteria
      # @return [Enumerator] If no block is given, returns an enumerator
      def find(*paths)
        block_given? or return enum_for(__method__, *paths)
        paths.collect! { |d| d.dup }
        while path = paths.shift
          path = prepare_path(path)
          catch(:prune) do
            stat = path.finder_stat or next
            visit_path?(path) and yield path
            if stat.directory?
              ps = protect_from_errors { Dir.entries(path) } or next
              ps.sort!
              ps.reverse_each do |p|
                next if p == "." or p == ".."
                next if !@show_hidden && p.start_with?('.')
                p = File.join(path, p)
                paths.unshift p
              end
            end
          end
        end
      end

      # Prepares a path for processing by extending it with PathExtension
      #
      # @param path [String] The path to prepare
      # @return [String] The prepared path object
      def prepare_path(path)
        path = path.dup
        path.extend PathExtension
        path.finder = self
        path
      end

      # Executes a block while protecting against expected standard errors
      #
      # @param errors [Array<Class>] Array of error classes to catch
      # @yield [] the block to be protected
      # @return [Object, nil] The result of the block or nil on error
      def protect_from_errors(errors = Find::EXPECTED_STANDARD_ERRORS)
        yield
      rescue errors
        raise_errors and raise
        return
      end
    end

    # Performs a depth-first search of the specified paths, yielding each
    # matching path to the block
    #
    # @param paths [Array<String>] The root paths to search
    # @param opts [Hash] Configuration options
    # @option opts [Boolean] :show_hidden (true) Whether to include hidden files/directories
    # @option opts [Boolean] :raise_errors (false) Whether to raise exceptions on errors
    # @option opts [Boolean] :follow_symlinks (true) Whether to follow symbolic links
    # @option opts [Array<String, Symbol>] :suffix (nil) Filter by file extension(s)
    # @option opts [Proc] :visit (nil) Custom filter predicate
    # @yield [String] Each path that matches the criteria
    # @return [Enumerator] If no block is given, returns an enumerator
    #
    # @example Basic usage
    #   Tins::Find.find('/path/to/directory') do |path|
    #     puts path
    #   end
    #
    # @example Find only Ruby files
    #   Tins::Find.find('/path/to/directory', suffix: 'rb') do |path|
    #     puts path
    #   end
    def find(*paths, **opts, &block)
      Finder.new(opts).find(*paths, &block)
    end

    # Skips the current path or directory, restarting the loop with the next
    # entry. Meaningful only within the block associated with Find.find.
    #
    # @example Skip directories
    #   Tins::Find.find('/path/to/directory') do |path|
    #     if path.count(?/) < 3
    #       Tins::Find.prune  # Skip all paths deeper than 2
    #     else
    #       puts path
    #     end
    #   end
    def prune
      throw :prune
    end

    module_function :find, :prune
  end
end
