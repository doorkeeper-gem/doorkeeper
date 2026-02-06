require "appraisal/bundler_dsl"
require "appraisal/utils"

module Appraisal
  class Conditional < BundlerDSL
    def initialize(condition)
      super()
      @condition = condition
    end

    def to_s
      "install_if #{@condition} do\n#{indent(super)}\nend"
    end

    # :nodoc:
    def for_dup
      "install_if #{@condition} do\n#{indent(super)}\nend"
    end
  end
end
