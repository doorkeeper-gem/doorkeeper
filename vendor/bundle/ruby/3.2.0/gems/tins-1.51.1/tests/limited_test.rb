require 'test_helper'

module Tins
  class LimitedTest < Test::Unit::TestCase
    def test_process_with
      count = {}
      Tins::Limited.new(5, name: 'sleeper').process do |limited|
        10.times do
          limited.execute do
            count[Thread.current] = true
            sleep 1
          end
        end
        until count.size >= 10
          sleep 0.1
        end
        limited.stop
      end
      assert_equal 10, count.keys.uniq.size
    end
  end
end
