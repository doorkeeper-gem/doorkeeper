require 'tins/proc_compose'

module Tins
  class ::Proc
    include Tins::ProcCompose
  end

  class ::Method
    include Tins::ProcCompose
  end
end
