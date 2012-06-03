module Doorkeeper
  module Models
    module Mongoid
      module Scopes
        def self.included(base)
          base.class_eval do
            def scopes=(value)
              write_attribute :scopes, value if value.present?
            end
          end
        end
      end
    end
  end
end
