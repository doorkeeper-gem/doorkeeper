module Doorkeeper
  module Models
    module MongoMapper
      module Revocable
        def self.included(base)
          base.class_eval do
            def update_column(attr, val)
              update_attribute attr, val
            end
          end
        end
      end
    end
  end
end
