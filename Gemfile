# Defaults. For supported versions check .travis.yml
ENV['orm'] ||= 'active_record'
ENV['rails'] ||= %w(active_record mongoid4).include?(ENV['orm']) ? '4.1' : '3.2'

source 'https://rubygems.org'

# Define Rails version
gem 'rails', "~> #{ENV['rails']}"

gem 'database_cleaner' if ENV['rails'][0] == '4'

case ENV['orm']
when 'active_record'
  gem 'activerecord'

when 'mongoid2'
  gem 'mongoid', '~> 2'
  gem 'bson_ext', '~> 1.7'

when 'mongoid3'
  gem 'mongoid', '~> 3'

when 'mongoid4'
  gem 'mongoid', '~> 4'
  gem 'moped'

when 'mongo_mapper'
  gem 'mongo_mapper', '~> 0.12'
  gem 'bson_ext', '~> 1.7'

else
  fail "Invalid ENV['orm']: #{ENV['orm']}."

end

gemspec
