require 'test_helper'
require 'tins/xt/p'

module Tins
  class PTest < Test::Unit::TestCase
    def test_p_bang
      assert_raise(RuntimeError) { p! "foo" }
    end

    def test_pp_bang
      assert_raise(RuntimeError) { pp! "foo" }
    end
  end
end
