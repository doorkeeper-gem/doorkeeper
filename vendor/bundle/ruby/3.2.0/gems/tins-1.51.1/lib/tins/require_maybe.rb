module Tins
  # A module that provides a safe require mechanism with optional error handling.
  #
  # This module is included in Object, making the `require_maybe` method globally
  # available throughout your Ruby application. It enables conditional loading of
  # libraries where the failure to load a dependency is not necessarily an error
  # condition, making it ideal for optional dependencies and feature detection.
  #
  # @example Basic usage anywhere in your codebase
  #   # Available globally:
  #   require_maybe 'foo'  # Returns true/false
  #
  # @example Providing fallback behavior
  #   class MyParser
  #     def parse_data(data)
  #       if require_maybe('foo')
  #         Foo::Parser.parse(data)
  #       else
  #         Bar.parse(data)  # Fallback
  #       end
  #     end
  #   end
  #
  # @example With error handling block
  #   require_maybe 'some_gem' do |error|
  #     puts "Optional gem 'some_gem' not available: #{error.message}"
  #   end
  module RequireMaybe
    # Attempts to require a library, gracefully handling LoadError exceptions.
    #
    # This method is globally available because the module is included in
    # Object. It's particularly useful for optional dependencies and feature
    # detection.
    #
    # @param library [String] The name of the library to require
    # @yield [LoadError] Optional block to handle the LoadError
    # @yieldparam error [LoadError] The rescued LoadError exception
    # @return [Boolean] Returns true if library was loaded successfully, false otherwise
    def require_maybe(library)
      require library
    rescue LoadError => e
      block_given? and yield e
    end
  end
end
