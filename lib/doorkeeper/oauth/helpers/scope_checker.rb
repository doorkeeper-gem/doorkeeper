module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.valid?(scope_str, server_scopes, application_scopes = nil)
          @valid_scopes = if application_scopes.present?
                            server_scopes & application_scopes
                          else
                            server_scopes
                          end

          @parsed_scopes = OAuth::Scopes.from_string(scope_str)
          scope_str.present? &&
            scope_str !~ /[\n|\r|\t]/ &&
            @valid_scopes.has_scopes?(@parsed_scopes)
        end

        def self.match?(scope_str, server_scopes, application_scopes = nil)
          valid?(scope_str, server_scopes, application_scopes) &&
            @parsed_scopes.has_scopes?(@valid_scopes)
        end

      end
    end
  end
end
