require 'rspec/expectations/expectation_target'
require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/string/filters'
require 'active_support/concern'
require 'appraisal/utils'
require "./spec/support/dependency_helpers"

module AcceptanceTestHelpers
  extend ActiveSupport::Concern
  include DependencyHelpers

  BUNDLER_ENVIRONMENT_VARIABLES = %w(RUBYOPT BUNDLE_PATH BUNDLE_BIN_PATH
    BUNDLE_GEMFILE)

  included do
    metadata[:type] = :acceptance

    before :parallel => true do
      unless Appraisal::Utils.support_parallel_installation?
        pending 'This Bundler version does not support --jobs flag.'
      end
    end

    before do
      cleanup_artifacts
      save_environment_variables
      unset_bundler_environment_variables
      build_default_dummy_gems
      ensure_bundler_is_available
      add_binstub_path
      build_default_gemfile
    end

    after do
      restore_environment_variables
    end
  end

  def save_environment_variables
    @original_environment_variables = {}

    (BUNDLER_ENVIRONMENT_VARIABLES + %w(PATH)).each do |key|
      @original_environment_variables[key] = ENV[key]
    end
  end

  def unset_bundler_environment_variables
    BUNDLER_ENVIRONMENT_VARIABLES.each do |key|
      ENV[key] = nil
    end
  end

  def add_binstub_path
    ENV['PATH'] = "bin:#{ENV['PATH']}"
  end

  def restore_environment_variables
    @original_environment_variables.each_pair do |key, value|
      ENV[key] = value
    end
  end

  def build_appraisal_file(content)
    write_file 'Appraisals', content.strip_heredoc
  end

  def build_gemfile(content)
    write_file 'Gemfile', content.strip_heredoc
  end

  def add_gemspec_to_gemfile
    in_test_directory do
      File.open('Gemfile', 'a') { |file| file.puts 'gemspec' }
    end
  end

  def build_gemspec
    write_file "stage.gemspec", <<-gemspec
      Gem::Specification.new do |s|
        s.name = 'stage'
        s.version = '0.1'
        s.summary = 'Awesome Gem!'
        s.authors = "Appraisal"
      end
    gemspec
  end

  def content_of(path)
    file(path).read.tap do |content|
      content.gsub!(/(\S+): /, ":\\1 => ")
    end
  end

  def file(path)
    Pathname.new(current_directory) + path
  end

  def be_exists
    be_exist
  end

  private

  def current_directory
    File.expand_path('tmp/stage')
  end

  def write_file(filename, content)
    in_test_directory { File.open(filename, 'w') { |file| file.puts content } }
  end

  def cleanup_artifacts
    FileUtils.rm_rf current_directory
  end

  def build_default_dummy_gems
    FileUtils.mkdir_p(TMP_GEM_ROOT)

    build_gem 'dummy', '1.0.0'
    build_gem 'dummy', '1.1.0'
  end

  def ensure_bundler_is_available
    run "bundle -v 2>&1", false

    if $?.exitstatus != 0
      puts <<-WARNING.squish.strip_heredoc
        Reinstall Bundler to #{TMP_GEM_ROOT} as `BUNDLE_DISABLE_SHARED_GEMS`
        is enabled.
      WARNING
      version = Utils.bundler_version

      run "gem install bundler --version #{version} --install-dir '#{TMP_GEM_ROOT}'"
    end
  end

  def build_default_gemfile
    build_gemfile <<-Gemfile
      source 'https://rubygems.org'

      gem 'appraisal', :path => '#{PROJECT_ROOT}'
    Gemfile

    run "bundle install --local"
    run "bundle binstubs --all"
  end

  def in_test_directory(&block)
    FileUtils.mkdir_p current_directory
    Dir.chdir current_directory, &block
  end

  def run(command, raise_on_error = true)
    in_test_directory do
      `#{command}`.tap do |output|
        exitstatus = $?.exitstatus

        if ENV["VERBOSE"]
          puts output
        end

        if raise_on_error && exitstatus != 0
          raise RuntimeError, <<-error_message.strip_heredoc
            Command #{command.inspect} exited with status #{exitstatus}. Output:
            #{output.gsub(/^/, '  ')}
          error_message
        end
      end
    end
  end
end
