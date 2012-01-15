module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.matches?(scopes, scopes_as_string)
          return false if scopes.nil? || scopes_as_string.nil?
          scopes_as_array = scopes_as_string.split(" ").map(&:to_sym)
          scopes.sort == scopes_as_array.sort
        end
      end
    end
  end
end
