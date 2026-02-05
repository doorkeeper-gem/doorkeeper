require 'tins/time_dummy'

module Tins
  class ::Time
    include TimeDummy
  end
end
