module Tins
  # Provides version string parsing and comparison functionality.
  #
  # This module allows working with semantic version strings in a more intuitive way,
  # supporting operations like comparison, incrementing, and accessing individual components.
  #
  # @example Basic usage
  #   version = "1.2.3".version
  #   puts version.major # => 1
  #   puts version.minor # => 2
  #   puts version.build # => 3
  #
  # @example Comparison operations
  #   v1 = "1.2.3".version
  #   v2 = "1.2.4".version
  #   puts v1 < v2       # => true
  #   puts v1 == v2      # => false
  #
  # @example Version manipulation
  #   version = "1.2.3".version
  #   version.bump(:minor) # => "1.3.0"
  #   version.succ!        # increments last component
  module StringVersion
    # Map of version level symbols to their numeric indices
    LEVELS = [ :major, :minor, :build, :revision ].each_with_index.
      each_with_object({}) { |(k, v), h| h[k] = v }
    symbols = LEVELS.invert.freeze
    LEVELS[:patch] = LEVELS[:build]
    LEVELS.freeze

    # Inverted map of LEVELS for symbol lookup
    SYMBOLS = symbols.freeze

    # Represents a version string with semantic comparison capabilities
    #
    # @example Creating a Version object
    #   version = Tins::StringVersion::Version.new("1.2.3")
    #
    # @example Accessing components
    #   v = "1.2.3".version
    #   puts v.major # => 1
    #   puts v.minor # => 2
    #   puts v.build # => 3
    class Version
      include Comparable

      # Creates a new version object from a string representation
      #
      # @param string [String] The version string (e.g., "1.2.3")
      # @raise [ArgumentError] If the string doesn't match a valid version pattern
      # @example
      #   Tins::StringVersion::Version.new("1.2.3")
      #   # => #<Tins::StringVersion::Version:0x00007f8b8c0b0a80 @version="1.2.3">
      def initialize(string)
        string =~ /\A\d+(\.\d+)*\z/ or
          raise ArgumentError, "#{string.inspect} isn't a version number"
        @version = string.frozen? ? string.dup : string
      end

      # Returns the major version component
      #
      # @return [Integer] The major version number
      # @example
      #   "1.2.3".version.major # => 1
      def major
        self[0]
      end

      # Sets the major version component
      #
      # @param new_level [Integer] The new major version number
      # @return [Integer] The updated major version number
      # @example
      #   v = "1.2.3".version
      #   v.major = 5 # sets major to 5
      def major=(new_level)
        self[0] = new_level
      end

      # Returns the minor version component
      #
      # @return [Integer] The minor version number
      # @example
      #   "1.2.3".version.minor # => 2
      def minor
        self[1]
      end

      # Sets the minor version component
      #
      # @param new_level [Integer] The new minor version number
      # @return [Integer] The updated minor version number
      # @example
      #   v = "1.2.3".version
      #   v.minor = 5 # sets minor to 5
      def minor=(new_level)
        self[1] = new_level
      end

      # Returns the build version component
      #
      # @return [Integer] The build version number
      # @example
      #   "1.2.3".version.build # => 3
      def build
        self[2]
      end

      # Alias for {#build} according to SemVer nomenclature
      alias patch build

      # Sets the build version component
      #
      # @param new_level [Integer] The new build version number
      # @return [Integer] The updated build version number
      # @example
      #   v = "1.2.3".version
      #   v.build = 5 # sets build to 5
      def build=(new_level)
        self[2] = new_level
      end

      # Alias for {#build=} according to SemVer nomenclature
      alias patch= build=

      # Returns the revision version component
      #
      # @return [Integer] The revision version number
      # @example
      #   "1.2.3".version.revision # => nil (no revision component)
      def revision
        self[3]
      end

      # Sets the revision version component
      #
      # @param new_level [Integer] The new revision version number
      # @return [Integer] The updated revision version number
      # @example
      #   v = "1.2.3".version
      #   v.revision = 5 # sets revision to 5
      def revision=(new_level)
        self[3] = new_level
      end

      # Increments a specified version component and resets subsequent components
      #
      # @param level [Symbol, Integer] The level to bump (default: last component)
      # @return [self] Returns self for chaining
      # @example
      #   v = "1.2.3".version
      #   v.bump(:minor) # => "1.3.0"
      #   v.bump         # => "1.3.1" (bumps last component)
      def bump(level = array.size - 1)
        level = level_of(level)
        self[level] += 1
        for l in level.succ..3
          self[l] &&= 0
        end
        self
      end

      # Converts a symbolic level to its numeric index
      #
      # @param specifier [Symbol, Integer] The level specification
      # @return [Integer] The corresponding numeric index
      def level_of(specifier)
        if specifier.respond_to?(:to_sym)
          LEVELS.fetch(specifier)
        else
          specifier
        end
      end

      # Gets a version component by index or symbol
      #
      # @param level [Symbol, Integer] The level to retrieve
      # @return [Integer] The version component value
      def [](level)
        array[level_of(level)]
      end

      # Sets a version component by index or symbol
      #
      # @param level [Symbol, Integer] The level to set
      # @param value [Integer] The new value for the component
      # @return [Integer] The updated value
      # @raise [ArgumentError] If value is negative
      def []=(level, value)
        level = level_of(level)
        value = value.to_i
        value >= 0 or raise ArgumentError,
          "version numbers can't contain negative numbers like #{value}"
        a = array
        a[level] = value
        a.map!(&:to_i)
        @version.replace a * ?.
      end

      # Increments the last version component
      #
      # @return [self] Returns self for chaining
      def succ!
        self[-1] += 1
        self
      end

      # Decrements the last version component
      #
      # @return [self] Returns self for chaining
      def pred!
        self[-1] -= 1
        self
      end

      # Compares this version with another
      #
      # @param other [Tins::StringVersion::Version] The version to compare against
      # @return [Integer] -1 if self < other, 0 if equal, 1 if self > other
      def <=>(other)
        pairs = array.zip(other.array)
        pairs.map! { |a, b| [ a.to_i, b.to_i ] }
        a, b = pairs.transpose
        a <=> b
      end

      # Checks equality with another version
      #
      # @param other [Tins::StringVersion::Version] The version to compare against
      # @return [Boolean] true if versions are equal
      def ==(other)
        (self <=> other).zero?
      end

      # Converts the version to an array of integers
      #
      # @return [Array<Integer>] Array representation of the version
      def array
        @version.split(?.).map(&:to_i)
      end

      # Alias for {#array}
      alias to_a array

      # Returns the string representation of this version
      #
      # @return [String] The version string
      def to_s
        @version
      end

      # Creates a copy of this version object
      #
      # @param source [Tins::StringVersion::Version] Source version to copy from
      # @return [void]
      def initialize_copy(source)
        super
        @version = source.instance_variable_get(:@version).dup
      end

      # Alias for {#to_s}
      alias inspect to_s
    end

    # Creates a Version object from this string
    #
    # @return [Tins::StringVersion::Version] The version object
    def version
      Version.new(self)
    end

    # Compares two version strings using the specified operator
    #
    # @param version1 [String] First version string
    # @param operator [Symbol] Comparison operator (:<, :<=, :==, :>=, :>)
    # @param version2 [String] Second version string
    # @return [Boolean] Result of the comparison
    def self.compare(version1, operator, version2)
      Version.new(version1).send(operator, Version.new(version2))
    end
  end

  # Creates a Version object directly from a string-like object
  #
  # @param string [String] The version string
  # @return [Tins::StringVersion::Version] The version object
  def self.StringVersion(string)
    StringVersion::Version.new(string.to_str)
  end
end
