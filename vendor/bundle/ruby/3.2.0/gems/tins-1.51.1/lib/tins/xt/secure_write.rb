require 'tins/secure_write'

module Tins
  class ::IO
    extend Tins::SecureWrite
  end
end
