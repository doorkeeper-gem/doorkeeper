require "appraisal/bundler_dsl"
require 'appraisal/utils'

module Appraisal
  class Platform < BundlerDSL
    def initialize(platform_names)
      super()
      @platform_names = platform_names
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
platforms #{Utils.format_arguments(@platform_names)} do
#{output_dependencies}
end
      OUTPUT
    end
  end
end
