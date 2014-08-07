module Doorkeeper
  module Models
    module Mongoid
      module Scopes
        extend ActiveSupport::Concern

        def scopes=(value)
          write_attribute :scopes, value if value.present?
        end
      end
    end
  end
end
