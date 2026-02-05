# frozen_string_literal: true

require 'thor'

module Coveralls
  class CommandLine < Thor
    desc 'push', 'Runs your test suite and pushes the coverage results to Coveralls.'
    def push
      return unless can_run_locally?

      ENV['COVERALLS_RUN_LOCALLY'] = 'true'
      cmds = ['bundle exec rake']

      if File.exist?('.travis.yml')
        cmds = begin
          YAML.load_file('.travis.yml')['script'] || cmds
        rescue StandardError
          cmds
        end
      end

      cmds.each { |cmd| system cmd }

      ENV['COVERALLS_RUN_LOCALLY'] = nil
    end

    desc 'report', 'Runs your test suite locally and displays coverage statistics.'
    def report
      ENV['COVERALLS_NOISY'] = 'true'

      exec 'bundle exec rake'

      ENV['COVERALLS_NOISY'] = nil
    end

    desc 'open', 'View this repository on Coveralls.'
    def open
      open_token_based_url 'https://coveralls.io/repos/%@'
    end

    desc 'service', "View this repository on your CI service's website."
    def service
      open_token_based_url 'https://coveralls.io/repos/%@/service'
    end

    desc 'last', 'View the last build for this repository on Coveralls.'
    def last
      open_token_based_url 'https://coveralls.io/repos/%@/last_build'
    end

    desc 'version', 'See version'
    def version
      Coveralls::Output.puts Coveralls::VERSION
    end

    private

    def config
      Coveralls::Configuration.configuration
    end

    def open_token_based_url(url)
      if config[:repo_token]
        url = url.gsub('%@', config[:repo_token])
        `open #{url}`
      else
        Coveralls::Output.puts 'No repo_token configured.'
      end
    end

    def can_run_locally?
      if config[:repo_token].nil?
        Coveralls::Output.puts 'Coveralls cannot run locally because no repo_secret_token is set in .coveralls.yml', color: 'red'
        Coveralls::Output.puts 'Please try again when you get your act together.', color: 'red'

        return false
      end

      true
    end
  end
end
