require 'appraisal/dependency'
require "set"

module Appraisal
  class DependencyList
    def initialize
      @dependencies = Hash.new
      @removed_dependencies = Set.new
    end

    def add(name, requirements)
      unless @removed_dependencies.include?(name)
        @dependencies[name] = Dependency.new(name, requirements)
      end
    end

    def remove(name)
      if @removed_dependencies.add?(name)
        @dependencies.delete(name)
      end
    end

    def to_s
      @dependencies.values.map(&:to_s).join("\n")
    end

    # :nodoc:
    def for_dup
      @dependencies.values.map(&:for_dup).join("\n")
    end
  end
end
