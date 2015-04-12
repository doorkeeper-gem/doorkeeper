gemfile = 'gemfiles/Gemfile.common.rb'
instance_eval IO.read(gemfile), gemfile

gem 'mongo_mapper'
gem 'bson_ext'
