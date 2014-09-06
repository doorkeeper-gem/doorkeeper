module Doorkeeper
  module Models
    module Mongoid
      module Scopes
        extend ActiveSupport::Concern

        # It's strange that if not define these after included will raise error in Mongoid 2 and 3, but 4 works well
        # see: https://travis-ci.org/jasl/doorkeeper/builds/31586902
        included do
          def scopes=(value)
            write_attribute :scopes, value if value.present?
          end
        end
      end
    end
  end
end
