require 'tins/null'

module Tins
  ::NULL = Tins::NULL

  class ::Object
    include Tins::Null::Kernel
  end
end
