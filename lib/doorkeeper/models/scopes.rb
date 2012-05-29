module Doorkeeper
  module Models
    module Scopes
      def self.included(base)
        base.class_eval do
          define_method :scopes do
            Doorkeeper::OAuth::Scopes.from_string(self[:scopes])
          end

          define_method :scopes_string do
            Doorkeeper::OAuth::Scopes.from_string(self[:scopes]).to_s
          end
        end
      end
    end
  end
end
