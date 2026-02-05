# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'

module Coveralls
  class RakeTask < ::Rake::TaskLib
    include ::Rake::DSL if defined?(::Rake::DSL)

    def initialize(*_args) # rubocop:disable Lint/MissingSuper
      namespace :coveralls do
        desc 'Push latest coverage results to Coveralls.io'
        task :push do
          require 'coveralls'

          Coveralls.push!
        end
      end
    end
  end
end
