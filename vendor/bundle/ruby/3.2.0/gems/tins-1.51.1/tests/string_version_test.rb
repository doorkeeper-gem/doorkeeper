# frozen_string_literal: false
#
require 'test_helper'
require 'tins/xt/string_version'

module Tins
  class StringVersionTest < Test::Unit::TestCase
    def test_comparison
      assert_operator '1.2'.version, :<, '1.3'.version
      assert_operator '1.3'.version, :>, '1.2'.version
      assert_operator '1.2'.version, :<=, '1.2'.version
      assert_operator '1.2'.version, :>=, '1.2'.version
      assert_operator '1.2'.version, :==, '1.2'.version
    end

    def test_change
      s = '1.2'
      s.version.revision = 1
      assert_equal '1.2.0.1', s
      s.version.revision += 1
      assert_equal '1.2.0.2', s
      s.version.succ!
      assert_equal '1.2.0.3', s
      s.version.pred!
      assert_equal '1.2.0.2', s
      assert_raise(ArgumentError) { s.version.build -= 1 }
      s.version.major = 2
      assert_equal '2.2.0.2', s
      s.version.minor = 1
      assert_equal '2.1.0.2', s
    end

    def test_bump
      s = '1.2.3'
      assert_equal '2.0.0', s.version.bump(:major).to_s
      s = '1.2.3'
      assert_equal '1.3.0', s.version.bump(:minor).to_s
      s = '1.2.3'
      assert_equal '1.2.4', s.version.bump(:build).to_s
      s = '1.2.3'
      assert_equal '1.2.4', s.version.bump.to_s
    end

    def test_dup
      s = '1.2.3'
      v = s.version
      w = v.dup
      v.succ!
      assert_equal '1.2.4', v.to_s
      assert_equal '1.2.3', w.to_s
    end

    def test_clone
      s = '1.2.3'
      v = s.version
      w = v.clone
      v.succ!
      assert_equal '1.2.4', v.to_s
      assert_equal '1.2.3', w.to_s
    end

    def test_patch_getter
      s = '1.2.3'
      assert_equal 3, s.version.patch
      assert_equal s.version.patch, s.version.build
    end

    def test_patch_setter
      s = '1.2.3'
      s.version.patch = 5
      assert_equal 5, s.version.patch
      assert_equal s.version.patch, s.version.build
    end
  end
end
