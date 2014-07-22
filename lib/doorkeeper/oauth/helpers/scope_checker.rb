module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.matches?(current_scopes, scopes)
          return false if current_scopes.nil? || scopes.nil?
          current_scopes == scopes
        end

        def self.valid?(scope, server_scopes)
          scope.present? &&
          scope !~ /[\n|\r|\t]/ &&
          server_scopes.has_scopes?(OAuth::Scopes.from_string(scope))
        end
      end
    end
  end
end
