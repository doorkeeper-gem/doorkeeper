require "shellwords"

module Appraisal
  # Executes commands with a clean environment
  class Command
    attr_reader :command, :env, :gemfile

    def initialize(command, options = {})
      @gemfile = options[:gemfile]
      @env = options.fetch(:env, {})
      @command = command_starting_with_bundle(command)
    end

    def run
      run_env = test_environment.merge(env)

      Bundler.with_original_env do
        ensure_bundler_is_available
        announce

        ENV["BUNDLE_GEMFILE"] = gemfile
        ENV["APPRAISAL_INITIALIZED"] = "1"
        run_env.each_pair do |key, value|
          ENV[key] = value
        end

        unless Kernel.system(command_as_string)
          exit(1)
        end
      end
    end

    private

    def ensure_bundler_is_available
      version = Utils.bundler_version
      unless system %(gem list --silent -i bundler -v #{version})
        puts ">> Reinstall Bundler into #{ENV["GEM_HOME"]}"

        unless system "gem install bundler --version #{version}"
          puts
          puts <<-ERROR.strip.gsub(/\s+/, " ")
            Bundler installation failed.
            Please try running:
              `GEM_HOME="#{ENV["GEM_HOME"]}" gem install bundler --version #{version}`
            manually.
          ERROR
          exit(1)
        end
      end
    end

    def announce
      if gemfile
        puts ">> BUNDLE_GEMFILE=#{gemfile} #{command_as_string}"
      else
        puts ">> #{command_as_string}"
      end
    end

    def command_starts_with_bundle?(original_command)
      if original_command.is_a?(Array)
        original_command.first =~ /^bundle/
      else
        original_command =~ /^bundle/
      end
    end

    def command_starting_with_bundle(original_command)
      if command_starts_with_bundle?(original_command)
        original_command
      else
        %w(bundle exec) + original_command
      end
    end

    def command_as_string
      if command.is_a?(Array)
        Shellwords.join(command)
      else
        command
      end
    end

    def test_environment
      return {} unless ENV["APPRAISAL_UNDER_TEST"] == "1"

      {
        "GEM_HOME" => ENV["GEM_HOME"],
        "GEM_PATH" => "",
      }
    end
  end
end
