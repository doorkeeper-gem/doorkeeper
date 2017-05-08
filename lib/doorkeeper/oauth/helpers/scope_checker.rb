module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        class Validator
          attr_reader :parsed_scopes, :scope_str

          def initialize(scope_str, server_scopes, application_scopes)
            @parsed_scopes = OAuth::Scopes.from_string(scope_str)
            @scope_str = scope_str
            @server_scopes = server_scopes
            @valid_scopes = valid_scopes(server_scopes, application_scopes)
          end

          def valid?
            scope_str.present? &&
              scope_str !~ /[\n\r\t]/ &&
              @valid_scopes.has_scopes?(parsed_scopes)
          end

          def match?
            valid? && parsed_scopes.has_scopes?(@valid_scopes)
          end

          def match_exactly?
            server_scopes_array = @server_scopes.to_a.uniq.sort
            match? && (server_scopes_array == parsed_scopes.to_a.sort)
          end

          private

          def valid_scopes(server_scopes, application_scopes)
            if application_scopes.present?
              application_scopes
            else
              server_scopes
            end
          end
        end

        def self.valid?(scope_str, server_scopes, application_scopes = nil)
          Validator.new(scope_str, server_scopes, application_scopes).valid?
        end

        def self.match?(scope_str, server_scopes, application_scopes = nil)
          Validator.new(scope_str, server_scopes, application_scopes).match?
        end

        def self.match_exactly?(scope_str, server_scopes, application_scopes = nil)
          Validator.new(scope_str, server_scopes, application_scopes).match_exactly?
        end
      end
    end
  end
end
