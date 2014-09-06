require 'rubygems'
require 'bundler/setup'

DOORKEEPER_ORM = :active_record unless defined?(DOORKEEPER_ORM)

$LOAD_PATH.unshift File.expand_path('../../../../lib', __FILE__)
