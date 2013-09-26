# Defaults. For supported versions check .travis.yml
ENV['rails'] ||= '3.2.8'
ENV['orm']   ||= 'active_record'

source 'https://rubygems.org'

gem 'jquery-rails'

# Define Rails version
rails_version = ENV['rails'].match(/edge/) ? {:github => 'rails/rails'} : ENV['rails']
gem 'rails', rails_version

gem 'database_cleaner', '~> 1.0.0.RC1' if rails_version.is_a?(Hash)

case ENV['orm']
when 'active_record'
  gem 'activerecord'

when 'mongoid2'
  gem 'mongoid', '2.5.1'
  gem 'bson_ext', '~> 1.7'

when 'mongoid3'
  gem 'mongoid', '3.0.10'

when 'mongoid4'
  gem 'mongoid', github: 'mongoid/mongoid', branch: 'master'

when 'mongo_mapper'
  gem 'mongo_mapper', '0.12.0'
  gem 'bson_ext', '~> 1.7'

end

gemspec
