gemfile = 'gemfiles/Gemfile.common.rb'
instance_eval IO.read(gemfile), gemfile

gem 'mongo_mapper', '~> 0.12'
gem 'bson_ext', '~> 1.7'
