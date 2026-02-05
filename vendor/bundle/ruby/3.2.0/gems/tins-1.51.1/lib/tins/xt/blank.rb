module Tins
  # The Tins::Blank module provides a consistent way to check if objects are
  # "blank" (empty, nil, or contain only whitespace). This follows Rails'
  # convention.
  #
  # @example Basic usage
  #   "".blank?        # => true
  #   "   ".blank?     # => true
  #   "foo".blank?     # => false
  #   [].blank?        # => true
  #   [1, 2].blank?    # => false
  #   nil.blank?       # => true
  #   false.blank?     # => true
  #   true.blank?      # => false
  #
  # @example Using present?
  #   "".present?      # => false
  #   "foo".present?   # => true
  module Blank
    # Blank behavior for Object instances
    module Object
      # Provides a fallback implementation that checks for `empty?` method,
      # falling back to negation of truthiness if not defined.
      #
      # @return [Boolean] true if the object is considered blank, false otherwise
      def blank?
        respond_to?(:empty?) ? empty? : !self
      end

      # Checks if the object is not blank
      #
      # @return [Boolean] true if the object is present, false otherwise
      def present?
        !blank?
      end
    end

    # Blank behavior for NilClass instances
    module NilClass
      #
      # Nil values are always considered blank.
      #
      # @return [Boolean] true (always)
      def blank?
        true
      end
    end

    # Blank behavior for FalseClass instances
    module FalseClass
      # False values are always considered blank.
      #
      # @return [Boolean] true (always)
      def blank?
        true
      end
    end

    # Blank behavior for TrueClass instances
    module TrueClass
      # True values are never considered blank.
      #
      # @return [Boolean] false (always)
      def blank?
        false
      end
    end

    # Blank behavior for Array instances
    #
    # Arrays are blank if they are empty.
    # This implementation aliases the `empty?` method to `blank?`.
    module Array
      # The included method is a hook that gets called when this module is
      # included in another class or module.
      #
      # It sets up blank? behavior by aliasing the empty? method to blank? in
      # the including class/module.
      #
      # @param modul [Object] the class or module that includes this module
      def self.included(modul)
        modul.module_eval do
          alias_method :blank?, :empty?
        end
      end
    end

    # Blank behavior for Hash instances
    #
    # Hashes are blank if they are empty.
    # This implementation aliases the `empty?` method to `blank?`.
    module Hash
      # The included method is a hook that gets called when this module is
      # included in another class or module.
      #
      # It sets up blank? behavior by aliasing the empty? method to blank? in
      # the including class/module.
      #
      # @param modul [Object] the class or module that includes this module
      def self.included(modul)
        modul.module_eval do
          alias_method :blank?, :empty?
        end
      end
    end

    # Blank behavior for String instances
    module String
      # Strings are blank if they contain only whitespace characters.
      # This uses a regex match against non-whitespace characters.
      #
      # @return [Boolean] true if the string contains only whitespace, false otherwise
      def blank?
        self !~ /\S/
      end
    end

    # Blank behavior for Numeric instances
    #
    # Numbers are considered blank only if they are zero.
    # This implementation aliases the `zero?` method to `blank?`.
    module Numeric
      # The included method is a hook that gets called when this module is
      # included in another class or module.
      #
      # It sets up blank? behavior by aliasing the zero? method to blank? in
      # the including class/module.
      #
      # @param modul [Object] the class or module that includes this module
      def self.included(modul)
        modul.module_eval do
          alias_method :blank?, :zero?
        end
      end
    end
  end
end

# Extend constant classes with Blank behavior unless blank? is already defined
unless Object.respond_to?(:blank?)
  for k in Tins::Blank.constants
    Object.const_get(k).class_eval do
      include Tins::Blank.const_get(k)
    end
  end
end
