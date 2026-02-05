require 'appraisal/utils'

module Appraisal
  class Gemspec
    attr_reader :options

    def initialize(options = {})
      @options = options
      @options[:path] ||= '.'
    end

    def to_s
      "gemspec #{Utils.format_string(exported_options)}"
    end

    # :nodoc:
    def for_dup
      "gemspec #{Utils.format_string(@options)}"
    end

    private

    def exported_options
      @options.merge(
        :path => Utils.prefix_path(@options[:path])
      )
    end
  end
end
