require 'tins/method_description'

module Tins
  class ::UnboundMethod
    include MethodDescription
  end

  class ::Method
    include MethodDescription
  end
end
