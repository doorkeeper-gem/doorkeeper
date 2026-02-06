module Mize::Configure
  attr_accessor :default_cache

  # Set the default cache object to +cache+.
  def cache(cache)
    self.default_cache = cache
  end

  # Configures Mize by executing a block of code and executing it in
  # configuration context/passing the configuration into it.
  def configure(&block)
    instance_eval(&block)
  end
end

module Mize
  extend Mize::Configure
end

Mize.default_cache = Mize::DefaultCache.new
