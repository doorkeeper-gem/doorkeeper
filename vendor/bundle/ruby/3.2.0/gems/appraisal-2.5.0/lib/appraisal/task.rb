require 'appraisal/appraisal_file'
require 'rake/tasklib'

module Appraisal
  # Defines tasks for installing appraisal dependencies and running other tasks
  # for a given appraisal.
  class Task < Rake::TaskLib
    def initialize
      namespace :appraisal do
        desc "DEPRECATED: Generate a Gemfile for each appraisal"
        task :gemfiles do
          warn "`rake appraisal:gemfile` task is deprecated and will be removed soon. " +
            "Please use `appraisal generate`."
          exec 'bundle exec appraisal generate'
        end

        desc "DEPRECATED: Resolve and install dependencies for each appraisal"
        task :install do
          warn "`rake appraisal:install` task is deprecated and will be removed soon. " +
            "Please use `appraisal install`."
          exec 'bundle exec appraisal install'
        end

        desc "DEPRECATED: Remove all generated gemfiles from gemfiles/ folder"
        task :cleanup do
          warn "`rake appraisal:cleanup` task is deprecated and will be removed soon. " +
            "Please use `appraisal clean`."
          exec 'bundle exec appraisal clean'
        end

        begin
          AppraisalFile.each do |appraisal|
            desc "DEPRECATED: Run the given task for appraisal #{appraisal.name}"
            task appraisal.name do
              ARGV.shift
              warn "`rake appraisal:#{appraisal.name}` task is deprecated and will be removed soon. " +
                "Please use `appraisal #{appraisal.name} rake #{ARGV.join(' ')}`."
              exec "bundle exec appraisal #{appraisal.name} rake #{ARGV.join(' ')}"
            end
          end
        rescue AppraisalsNotFound
        end

        task :all do
          ARGV.shift
          exec "bundle exec appraisal rake #{ARGV.join(' ')}"
        end
      end

      desc "Run the given task for all appraisals"
      task :appraisal => "appraisal:all"
    end
  end
end
