module Doorkeeper
  class Scope
    attr_reader :name, :default, :description

    def initialize(name, options = {})
      @name = name
      @default = options[:default] || false
      @description = options[:description]
    end
  end
end
