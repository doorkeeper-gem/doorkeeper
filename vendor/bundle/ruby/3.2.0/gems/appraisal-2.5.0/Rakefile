require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.ruby_opts = %w[-w]
  t.verbose = false
end

desc 'Default: run the rspec examples'
task :default => [:spec]
