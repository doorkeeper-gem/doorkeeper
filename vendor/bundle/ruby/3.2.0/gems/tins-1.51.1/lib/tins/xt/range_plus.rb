require 'tins/range_plus'

module Tins
  class ::Range
    if method_defined?(:+)
      warn "#{self}#+ already defined, didn't include at #{__FILE__}:#{__LINE__}"
    else
      include RangePlus
    end
  end
end

