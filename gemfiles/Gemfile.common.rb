ENV['rails'] ||= '4.2.0.rc2'

source 'https://rubygems.org'

gem 'rails', "~> #{ENV['rails']}"

if ENV['rails'][0] == '4'
  gem 'database_cleaner', '~> 1.3.0'
end
if ENV['rails'] =~ /4.0|3.2/
  gem 'rubysl-test-unit'
end

gemspec path: '../'
