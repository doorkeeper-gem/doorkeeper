module Doorkeeper
  module OAuth
    module Helpers
      module ScopeChecker
        class Validator
          attr_reader :parsed_scopes, :scope_str

          def initialize(scope_str, scopes_source, application)
            @parsed_scopes = OAuth::Scopes.from_string(scope_str)
            @scope_str = scope_str
            @valid_scopes = valid_scopes(scopes_source, application)
          end

          def valid?
            scope_str.present? &&
              scope_str !~ /[\n|\r|\t]/ &&
              @valid_scopes.has_scopes?(parsed_scopes)
          end

          def match?
            valid? && parsed_scopes.has_scopes?(@valid_scopes)
          end

          private

          def valid_scopes(scopes_source, application)
            if application
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
          end
        end

        def self.valid?(scope_str, scopes_source, application = nil)
          Validator.new(scope_str, scopes_source, application).valid?
        end

        def self.match?(scope_str, scopes_source, application = nil)
          Validator.new(scope_str, scopes_source, application).match?
        end
      end
    end
  end
end
