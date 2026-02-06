require "appraisal/bundler_dsl"

module Appraisal
  autoload :Gemspec, "appraisal/gemspec"
  autoload :Git, "appraisal/git"
  autoload :Group, "appraisal/group"
  autoload :Path, "appraisal/path"
  autoload :Platform, "appraisal/platform"
  autoload :Source, "appraisal/source"
  autoload :Conditional, "appraisal/conditional"

  # Load bundler Gemfiles and merge dependencies
  class Gemfile < BundlerDSL
    def load(path)
      run(IO.read(path), path) if File.exist?(path)
    end

    def run(definitions, path, line = 1)
      instance_eval(definitions, path, line) if definitions
    end

    def dup
      Gemfile.new.tap do |gemfile|
        gemfile.git_sources = @git_sources
        gemfile.run(for_dup, __FILE__, __LINE__)
      end
    end
  end
end
