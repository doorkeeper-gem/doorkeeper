ENV['rails'] ||= '4.2.0'

source 'https://rubygems.org'

gem 'rails', "~> #{ENV['rails']}"

if ENV['rails'] =~ /4.0|3.2/
  gem 'rubysl-test-unit'
end

gemspec path: '../'
