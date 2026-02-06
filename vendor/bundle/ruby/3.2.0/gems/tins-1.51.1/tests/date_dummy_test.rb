require 'test_helper'

module Tins
  class DateDummyTest < Test::Unit::TestCase
    require 'tins/xt/date_dummy'
    require 'date'

    def test_date_dummy
      date = Date.parse('2009-09-09')
      assert_not_equal date, Date.today
      Date.dummy = date
      assert_equal date, Date.today
      Date.dummy = nil
      assert_not_equal date, Date.today
    end

    def test_date_dummy_block
      date = Date.parse('2009-09-09')
      assert_not_equal date, Date.today
      Date.dummy date do
        assert_equal date, Date.today
        Date.dummy date + 1 do
          assert_equal date + 1, Date.today
        end
        assert_equal date, Date.today
      end
      assert_not_equal date, Date.today
    end
  end
end
