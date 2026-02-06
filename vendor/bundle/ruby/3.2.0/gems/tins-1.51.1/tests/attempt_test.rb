require 'test_helper'
require 'tins/xt'

module Tins
  class AttemptTest < Test::Unit::TestCase
    class MyError < StandardError; end

    class MyException < Exception; end

    def test_attempt_with_invalid_arguments
      assert_raise(ArgumentError) { attempt(attempts: 0) {  } }
    end

    def test_attempt_block_condition
      assert attempt(attempts: 1, exception_class: nil) { |c| c == 1 }
      assert attempt(attempts: 3, exception_class: nil) { |c| c == 1 }
      assert_equal false, attempt(attempts: 3, exception_class: nil) { |c| c == 4 }
      assert_raise(MyException) { attempt(attempts: 3, exception_class: nil) { raise MyException } }
    end

    def test_attempt_default_exception
      assert attempt(1) { |c| c != 1 and raise MyError }
      assert attempt(3) { |c| c != 1 and raise MyError }
      assert_equal false, attempt(3) { |c| c != 4 and raise MyError }
      assert_raise(Exception) { attempt(3) { raise Exception } }
    end

    def test_attempt_exception
      assert_equal false,
        attempt(attempts: 3, exception_class: MyException) { raise MyException }
      assert_equal true,
        attempt(attempts: 3, exception_class: MyException) { |c| c == 1 and raise MyException }
    end

    def test_reraise_exception_true
      tries = 0
      assert_raise(MyException) do
        attempt(attempts: 3, exception_class: MyException, reraise: true) do |c|
          tries = c; raise MyException
        end
      end
      assert_equal 3, tries
    end

    def test_reraise_exception_exception_class
      other_exception = Exception
      tries = 0
      assert_raise(other_exception) do
        attempt(attempts: 3, exception_class: MyException, reraise: other_exception) do |c|
          tries = c; raise MyException
        end
      end
      assert_equal 3, tries
    end

    def test_reraise_exception_proc
      other_exception = Exception
      tries = 0
      assert_raise(other_exception, 'hi ho') do
        attempt(attempts: 3, exception_class: MyException, reraise: -> e { raise  other_exception, 'hi ho' }) do |c|
          tries = c; raise MyException
        end
      end
      assert_equal 3, tries
    end

    def test_reraise_exception_with_positive_sleep
      tries = 0
      singleton_class.class_eval do
        define_method(:sleep_duration) do |duration, count|
          assert_equal 10, duration
          tries = count
          super 0, count # Let's not really sleep that long…
        end
      end
      assert_raise(MyException) do
        attempt(attempts: 3, exception_class: MyException, reraise: true, sleep: 10) do |c|
          raise MyException
        end
      end
      assert_equal 2, tries
    ensure
      singleton_class.class_eval do
        method_defined?(:sleep_duration) and remove_method :sleep_duration
      end
    end

    def test_reraise_exception_with_proc_sleep
      tries = 0
      singleton_class.class_eval do
        define_method(:sleep_duration) do |duration, count|
          assert_kind_of Proc, duration
          tries = count
          super duration, count
        end
      end
      assert_raise(MyException) do
        attempt(attempts: 3, exception_class: MyException, reraise: true, sleep: -> x { 0 }) do |c|
          raise MyException
        end
      end
      assert_equal 2, tries
    ensure
      singleton_class.class_eval do
        method_defined?(:sleep_duration) and remove_method :sleep_duration
      end
    end

    def test_reraise_exception_with_negative_sleep
      tries = 0
      sleeps = [ 2.701, 7.298 ]
      singleton_class.class_eval do
        define_method(:sleep_duration) do |duration, count|
          assert_in_delta sleeps[tries], duration.call(count), 1E-3
          tries = count
          super 0, count # Let's not really sleep that long…
        end
      end
      assert_raise(MyException) do
        attempt(attempts: 3, exception_class: MyException, reraise: true, sleep: -10) do |c|
          raise MyException
        end
      end
      assert_equal 2, tries
    ensure
      singleton_class.class_eval do
        method_defined?(:sleep_duration) and remove_method :sleep_duration
      end
    end

    def test_attempt_previous_exception_block_arg
      last_e = nil
      attempt(1) { |c, prev_e| last_e = prev_e }
      assert_nil last_e
      attempt(2) { |c, prev_e| last_e = prev_e; c == 1 and raise MyError }
      assert_kind_of MyError, last_e
      attempt(3) { |c, prev_e| last_e = prev_e; c == 1 and raise MyError }
      assert_kind_of MyError, last_e
      attempt(4) { |c, prev_e| last_e = prev_e; c == 1 and raise MyError; c == 2 and raise ArgumentError }
      assert_kind_of ArgumentError, last_e
    end
  end
end
