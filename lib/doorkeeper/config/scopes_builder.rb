module Doorkeeper
  class Config
    class ScopesBuilder
      def initialize(&block)
        @scopes = Doorkeeper::Scopes.new
        instance_eval &block
      end

      def build
        @scopes
      end

      def scope(name, options)
        @scopes.add Doorkeeper::Scope.new(name, options)
      end
    end
  end
end
