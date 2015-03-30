module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        def self.valid?(scope_str, scopes_source, application = nil)
          if scope_str.present? && scope_str !~ /[\n|\r|\t]/
            valid_scopes = if application
                             if application.scopes.present?
                               scopes_source.scopes & application.scopes
                             else
                               scopes_source.scopes
                             end
                           else
                             if scopes_source.respond_to? :default_scopes
                               scopes_source.default_scopes
                             else
                               scopes_source.scopes
                             end
                           end

            valid_scopes.has_scopes?(OAuth::Scopes.from_string(scope_str))
          else
            false
          end
        end
      end
    end
  end
end
