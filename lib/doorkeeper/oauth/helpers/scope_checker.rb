module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.valid?(scope_str, server_scopes, application_scopes = nil)
          valid_scopes = if application_scopes.present?
                           server_scopes & application_scopes
                         else
                           server_scopes
                         end

          scope_str.present? &&
            scope_str !~ /[\n|\r|\t]/ &&
            valid_scopes.has_scopes?(OAuth::Scopes.from_string(scope_str))
        end
      end
    end
  end
end
