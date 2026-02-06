require "appraisal/bundler_dsl"
require "appraisal/utils"

module Appraisal
  class Source < BundlerDSL
    def initialize(source)
      super()
      @source = source
    end

    def to_s
      formatted_output indent(super)
    end

    # :nodoc:
    def for_dup
      formatted_output indent(super)
    end

    private

    def formatted_output(output_dependencies)
      <<-OUTPUT.strip
source #{@source.inspect} do
#{output_dependencies}
end
        OUTPUT
    end
  end
end
