module Doorkeeper
  module Models
    module Scopes
      def scopes
        Doorkeeper::OAuth::Scopes.from_string(self[:scopes])
      end

      def scopes_string
        Doorkeeper::OAuth::Scopes.from_string(self[:scopes]).to_s
      end
    end
  end
end
