require 'test_helper'

module Tins
  class DeprecateTest < Test::Unit::TestCase
    class A < Array
      attr_reader :warned

      def warn(message)
        @warned = message if message =~ /DEPRECATION/
      end

      extend Tins::Deprecate
      deprecate method:
        def zum_felde
          to_a
        end,
        new_method: :to_a

      extend Tins::Deprecate
      deprecate method:
        def zum_vektor
          to_a
        end,
        message: '[DEPRECATION] method `%{method}` is obsolete.'
    end

    def test_deprecate
      a = A[ 1, 2 ]
      assert_nil a.warned
      assert_equal [ 1, 2 ], a.zum_felde
      assert_match(/zum_felde` is deprecated/, a.warned)
    end

    def test_deprecate_with_message
      a = A[ 1, 2 ]
      assert_nil a.warned
      assert_equal [ 1, 2 ], a.zum_vektor
      assert_match(/zum_vektor` is obsolete/, a.warned)
    end
  end
end
