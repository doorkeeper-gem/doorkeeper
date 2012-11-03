require 'rubygems'
require 'bundler/setup'

DOORKEEPER_ORM = (ENV['orm'] || :active_record).to_sym unless defined?(DOORKEEPER_ORM)

$:.unshift File.expand_path('../../../../lib', __FILE__)
