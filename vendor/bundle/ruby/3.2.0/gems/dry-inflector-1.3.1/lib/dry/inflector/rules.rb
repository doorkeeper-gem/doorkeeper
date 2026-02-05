# frozen_string_literal: true

module Dry
  class Inflector
    # A set of inflection rules
    #
    # @since 0.1.0
    # @api private
    class Rules
      # @since 0.1.0
      # @api private
      def initialize
        @rules = []
      end

      # @since 0.1.0
      # @api private
      def apply_to(word)
        matching_rule = @rules.find { |rule, _replacement| rule.match? word }
        if matching_rule
          word.gsub(matching_rule[0], matching_rule[1])
        else
          word
        end.dup
      end

      # @since 0.1.0
      # @api private
      def insert(index, array)
        @rules.insert(index, array)
      end
    end
  end
end
