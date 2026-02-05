require 'tins/partial_application'

module Tins
  class ::Proc
    include PartialApplication
  end

  class ::Method
    include PartialApplication
  end
end
