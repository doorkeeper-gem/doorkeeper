require 'test_helper'
require 'tins/xt/time_freezer'

module Tins
  class TimeFreezerTest < Test::Unit::TestCase
    def test_freezing
      freezing_point = '2011-11-11T11:11:11Z'
      Tins::TimeFreezer.freeze(freezing_point) do
        assert_equal "2011-11-11 11:11:11 UTC", Time.now.to_s
        assert_equal "2011-11-11T11:11:11+00:00", DateTime.now.to_s
        assert_equal "2011-11-11", Date.today.to_s
      end
    end

    def test_to_time_conversion
      freezing_point = '2011-11-11T11:11:11Z'
      time = Time.parse(freezing_point)
      Tins::TimeFreezer.freeze(time) do
        assert_equal "2011-11-11 11:11:11 UTC", Time.now.utc.to_s
        assert_equal "2011-11-11T11:11:11+00:00", DateTime.now.to_s
        assert_equal "2011-11-11", Date.today.to_s
      end
    end

    def test_to_date_conversion
      freezing_point = '2011-11-11Z'
      date = Date.parse(freezing_point)
      Tins::TimeFreezer.freeze(date) do
        assert_equal "2011-11", Time.now.utc.to_s[0, 7]
        assert_equal "2011-11", DateTime.now.to_s[0, 7]
        assert_equal "2011-11", Date.today.to_s[0, 7]
      end
    end

    def test_to_datetime_conversion
      freezing_point = '2011-11-11T11:11:11Z'
      datetime = DateTime.parse(freezing_point)
      Tins::TimeFreezer.freeze(datetime) do
        assert_equal "2011-11-11 11:11:11 UTC", Time.now.utc.to_s
        assert_equal "2011-11-11T11:11:11+00:00", DateTime.now.to_s
        assert_equal "2011-11-11", Date.today.to_s
      end
    end
  end
end
