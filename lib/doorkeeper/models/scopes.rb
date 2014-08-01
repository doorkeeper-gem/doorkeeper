module Doorkeeper
  module Models
    module Scopes
      def self.included(base)
        base.class_eval do
          define_method :scopes do
            OAuth::Scopes.from_string(self[:scopes])
          end

          define_method :scopes_string do
            OAuth::Scopes.from_string(self[:scopes]).to_s
          end

          define_method :includes_scope? do |required_scope|
            scopes.exists? required_scope.to_s
          end
        end
      end
    end
  end
end
