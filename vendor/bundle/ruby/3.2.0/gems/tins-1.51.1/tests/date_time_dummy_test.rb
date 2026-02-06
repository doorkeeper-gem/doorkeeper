require 'test_helper'

module Tins
  class DateTimeDummyTest < Test::Unit::TestCase
    require 'tins/xt/date_time_dummy'
    require 'date'

    def test_time_dummy
      date_time = DateTime.parse('2009-09-09 21:09:09')
      assert_not_equal date_time, DateTime.now
      DateTime.dummy = date_time
      assert_equal date_time, DateTime.now
      DateTime.dummy = nil
      assert_not_equal date_time, DateTime.now
    end

    def test_time_dummy_block
      date_time = DateTime.parse('2009-09-09 21:09:09')
      assert_not_equal date_time, DateTime.now
      DateTime.dummy date_time do
        assert_equal date_time, DateTime.now
        DateTime.dummy date_time + 1 do
          assert_equal date_time + 1, DateTime.now
        end
        assert_equal date_time, DateTime.now
      end
      assert_not_equal date_time, DateTime.now
    end
  end
end
