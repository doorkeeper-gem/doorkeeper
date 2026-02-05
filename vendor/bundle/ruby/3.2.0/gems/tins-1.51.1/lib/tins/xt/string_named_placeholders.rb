module Tins
  require 'tins/string_named_placeholders'

  class ::String
    include StringNamedPlaceholders
  end
end
