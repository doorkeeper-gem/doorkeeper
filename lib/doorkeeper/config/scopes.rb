module Doorkeeper
  class Scopes
    include Enumerable
    REQUIRED_ELEMENT_METHOD = [:name, :default]

    class IllegalElement < StandardError; end

    delegate :each, :to => :@scopes

    def initialize
      @scopes = []
    end

    def [](name)
      @scopes.select do |scope|
        scope.name.to_sym == name.to_sym
      end.first
    end

    def add (scope)
      raise IllegalElement unless valid_element?(scope)
      @scopes << scope
    end

    def all
      @scopes
    end

    def defaults
      @scopes.select do |scope|
        scope.default
      end
    end

    def default_scope_string
      defaults.map(&:name).join(" ")
    end

    def with_names(*names)
      names = names.map(&:to_sym)
      @scopes.select do |scope|
        names.include? scope.name.to_sym
      end
    end

    private
    def valid_element?(scope)
      REQUIRED_ELEMENT_METHOD.all? do |method|
        scope.respond_to? method
      end
    end
  end
end
