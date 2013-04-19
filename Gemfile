# Defaults. For supported versions check .travis.yml
ENV['rails'] ||= '3.2.8'
ENV['orm']   ||= 'active_record'

source 'https://rubygems.org'

gem 'jquery-rails'

# Define Rails version
rails_version = ENV['rails'].match(/edge/) ? {:github => 'rails/rails'} : ENV['rails']
gem 'rails', rails_version

case ENV['orm']
when 'active_record'
  gem 'activerecord'

when 'mongoid2'
  gem 'mongoid', '2.5.1'
  gem 'bson_ext', '~> 1.7'

when 'mongoid3'
  gem 'mongoid', '3.0.10'

when 'mongo_mapper'
  gem 'mongo_mapper', '0.12.0'
  gem 'bson_ext', '~> 1.7'

end

gemspec
