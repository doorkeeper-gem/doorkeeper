module Doorkeeper
  class RSpec
    # Print's useful information about env: Ruby / Rails versions,
    # Doorkeeper configuration, etc.
    def self.print_configuration_info
      puts <<-INFO.strip_heredoc
        ====> Doorkeeper ORM: '#{Doorkeeper.configuration.orm}'
        ====> Doorkeeper version: #{Doorkeeper.gem_version}
        ====> Rails version: #{::Rails.version}
        ====> Ruby version: #{RUBY_VERSION} on #{RUBY_PLATFORM}
      INFO
    end

    # Tries to find ORM from the Gemfile used to run test suite
    def self.detect_orm
      orm = (ENV['BUNDLE_GEMFILE'] || '').match(/Gemfile\.(.+)\.rb/)
      (orm && orm[1] || :active_record).to_sym
    end
  end
end
