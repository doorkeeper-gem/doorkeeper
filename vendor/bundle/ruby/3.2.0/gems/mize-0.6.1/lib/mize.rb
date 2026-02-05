require 'thread'

module Mize
  MUTEX = Mutex.new

  class << self
    attr_accessor :wrapped
  end
  self.wrapped = {}
end

require 'mize/version'
require 'mize/memoize'
require 'mize/configure'
require 'mize/global_clear'
require 'mize/railtie' if defined? Rails

class ::Module
  prepend Mize::Memoize
end
