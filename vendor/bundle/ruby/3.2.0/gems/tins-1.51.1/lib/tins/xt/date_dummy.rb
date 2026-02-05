require 'tins/date_dummy'

module Tins
  class ::Date
    include DateDummy
  end
end
