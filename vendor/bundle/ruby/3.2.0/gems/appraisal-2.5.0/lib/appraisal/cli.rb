require 'thor'
require 'fileutils'

module Appraisal
  class CLI < Thor
    default_task :install
    map ["-v", "--version"] => "version"

    # Override help command to print out usage
    def self.help(shell, subcommand = false)
      shell.say strip_heredoc(<<-help)
        Appraisal: Find out what your Ruby gems are worth.

        Usage:
          appraisal [APPRAISAL_NAME] EXTERNAL_COMMAND

          If APPRAISAL_NAME is given, only run that EXTERNAL_COMMAND against the given
          appraisal, otherwise it runs the EXTERNAL_COMMAND against all appraisals.
      help

      if File.exist?('Appraisals')
        shell.say
        shell.say 'Available Appraisal(s):'

        AppraisalFile.each do |appraisal|
          shell.say "  - #{appraisal.name}"
        end
      end

      shell.say

      super
    end

    def self.exit_on_failure?
      true
    end

    desc 'install', 'Resolve and install dependencies for each appraisal'
    method_option 'jobs', :aliases => 'j', :type => :numeric, :default => 1,
      :banner => 'SIZE',
      :desc => 'Install gems in parallel using the given number of workers.'
    method_option 'retry', :type => :numeric, :default => 1,
      :desc => 'Retry network and git requests that have failed'
    method_option "without", :banner => "GROUP_NAMES",
      :desc => "A space-separated list of groups referencing gems to skip " +
        "during installation. Bundler will remember this option."
    method_option "full-index", :type => :boolean,
                                :desc => "Run bundle install with the " \
                                         "full-index argument."
    method_option "path", type: :string,
                          desc: "Install gems in the specified directory. " \
                                "Bundler will remember this option."

    def install
      invoke :generate, [], {}

      AppraisalFile.each do |appraisal|
        appraisal.install(options)
        appraisal.relativize
      end
    end

    desc 'generate', 'Generate a gemfile for each appraisal'
    def generate
      AppraisalFile.each do |appraisal|
        appraisal.write_gemfile
      end
    end

    desc 'clean', 'Remove all generated gemfiles and lockfiles from gemfiles folder'
    def clean
      FileUtils.rm_f Dir['gemfiles/*.{gemfile,gemfile.lock}']
    end

    desc 'update [LIST_OF_GEMS]', 'Remove all generated gemfiles and lockfiles, resolve, and install dependencies again'
    def update(*gems)
      invoke :generate, []

      AppraisalFile.each do |appraisal|
        appraisal.update(gems)
      end
    end

    desc 'list', 'List the names of the defined appraisals'
    def list
      AppraisalFile.new.appraisals.each { |appraisal| puts appraisal.name }
    end

    desc "version", "Display the version and exit"
    def version
      puts "Appraisal #{VERSION}"
    end

    private

    def method_missing(name, *args, &block)
      matching_appraisal = AppraisalFile.new.appraisals.detect do |appraisal|
        appraisal.name == name.to_s
      end

      if matching_appraisal
        Command.new(args, :gemfile => matching_appraisal.gemfile_path).run
      else
        AppraisalFile.each do |appraisal|
          Command.new(ARGV, :gemfile => appraisal.gemfile_path).run
        end
      end
    end

    def self.strip_heredoc(string)
      indent = string.scan(/^[ \t]*(?=\S)/).min.size || 0
      string.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end
