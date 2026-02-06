require 'tins'

module Tins
  class ::Module
    include Tins::Constant
    include Tins::DSLAccessor
    include Tins::ClassMethod
    include Tins::Delegate
    include Tins::ParameterizedModule
    include Tins::FromModule
  end

  class ::Object
    include Tins::ThreadLocal
    include Tins::ThreadGlobal
    include Tins::Interpreter
    include Tins::Deflect
    include Tins::ThreadLocal
    include Tins::Eigenclass
    include Tins::BlockSelf
  end
end
