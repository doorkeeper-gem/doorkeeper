require 'rubygems'
require 'bundler/setup'

DOORKEEPER_ORM = (ENV['DOORKEEPER_ORM'] || :active_record).to_sym unless defined?(DOORKEEPER_ORM)

$:.unshift File.expand_path('../../../../lib', __FILE__)
