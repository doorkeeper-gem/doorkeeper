module Tins
  require 'tins/string_byte_order_mark'
  class ::String
    include StringByteOrderMark
  end
end

