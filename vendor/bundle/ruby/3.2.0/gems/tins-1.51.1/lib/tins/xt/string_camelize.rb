module Tins
  require 'tins/string_camelize'
  unless String.respond_to?(:camelize)
    class ::String
      include StringCamelize
    end
  end
end
