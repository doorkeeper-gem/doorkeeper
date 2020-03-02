require 'rubygems'
require 'bundler/setup'

orm = ENV['BUNDLE_GEMFILE'].match(/Gemfile\.(.+)\.rb/)
DOORKEEPER_ORM = (orm && orm[1]) || :active_record unless defined?(DOORKEEPER_ORM)

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)
