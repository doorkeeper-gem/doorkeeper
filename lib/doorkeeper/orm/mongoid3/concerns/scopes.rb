module Doorkeeper
  module Models
    module Mongoid3
      module Scopes
        extend ActiveSupport::Concern

        included do
          def scopes
            OAuth::Scopes.from_string(self[:scopes])
          end

          def scopes_string
            self[:scopes]
          end

          def includes_scope?(*required_scopes)
            required_scopes.blank? || required_scopes.any? { |s| scopes.exists?(s.to_s) }
          end
          
          def scopes=(value)
            write_attribute :scopes, value if value.present?
          end
        end
      end
    end
  end
end
