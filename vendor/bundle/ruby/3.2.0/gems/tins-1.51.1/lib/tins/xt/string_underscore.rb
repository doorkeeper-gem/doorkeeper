module Tins
  require 'tins/string_underscore'
  unless String.respond_to?(:underscore)
    class ::String
      include StringUnderscore
    end
  end
end
