gemfile = 'gemfiles/Gemfile.common.rb'
instance_eval IO.read(gemfile), gemfile

gem 'mongoid', '~> 3'
