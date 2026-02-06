require 'tins/deep_dup'

module Tins
  unless Object.respond_to?(:deep_dup)
    class ::Object
      include Tins::DeepDup
    end
  end
end
