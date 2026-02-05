require 'test_helper'

module Tins
  class TimeDummyTest < Test::Unit::TestCase
    require 'tins/xt/time_dummy'
    require 'time'

    def test_time_dummy
      time = Time.parse('2009-09-09 21:09:09')
      assert_not_equal time, Time.now
      Time.dummy = time
      assert_equal time, Time.now
      Time.dummy = nil
      assert_not_equal time, Time.now
    end

    def test_time_dummy_block
      time = Time.parse('2009-09-09 21:09:09')
      assert_not_equal time, Time.now
      Time.dummy time do
        assert_equal time, Time.now
        Time.dummy time + 1 do
          assert_equal time + 1, Time.now
        end
        assert_equal time, Time.now
      end
      assert_not_equal time, Time.now
    end
  end
end
