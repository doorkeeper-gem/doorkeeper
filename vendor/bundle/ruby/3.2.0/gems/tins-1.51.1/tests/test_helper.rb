begin
  require 'gem_hadar/simplecov'
  GemHadar::SimpleCov.start
rescue LoadError
end
begin
  require 'debug'
rescue LoadError
end
require 'test/unit'
require 'tins'
