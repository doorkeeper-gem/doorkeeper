module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.matches?(current_scopes, scopes)
          return false if current_scopes.nil? || scopes.nil?
          current_scopes.map(&:to_s).sort == scopes.split(" ").sort
        end
      end
    end
  end
end
