module Doorkeeper
  module Models
    module Mongoid
      module VersionCheck
        def self.included(base)
          base.class_eval do
            def self.is_mongoid_3_x?
              ::Mongoid::VERSION >= "3"
            end
          end
        end
      end
    end
  end
end