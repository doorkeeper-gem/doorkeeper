module Mize
  class Railtie < Rails::Railtie
    config.to_prepare do
      Mize.cache_clear
    end
  end
end
