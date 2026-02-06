require 'tins/date_time_dummy'

module Tins
  class ::DateTime
    include DateTimeDummy
  end
end
