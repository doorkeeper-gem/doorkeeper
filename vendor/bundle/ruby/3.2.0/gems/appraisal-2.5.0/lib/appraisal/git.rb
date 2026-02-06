require "appraisal/bundler_dsl"
require 'appraisal/utils'

module Appraisal
  class Git < BundlerDSL
    def initialize(source, options = {})
      super()
      @source = source
      @options = options
    end

    def to_s
      if @options.empty?
        "git #{Utils.prefix_path(@source).inspect} do\n#{indent(super)}\nend"
      else
        "git #{Utils.prefix_path(@source).inspect}, #{Utils.format_string(@options)} do\n" +
          "#{indent(super)}\nend"
      end
    end

    # :nodoc:
    def for_dup
      if @options.empty?
        "git #{@source.inspect} do\n#{indent(super)}\nend"
      else
        "git #{@source.inspect}, #{Utils.format_string(@options)} do\n" +
          "#{indent(super)}\nend"
      end
    end
  end
end
