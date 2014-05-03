module Doorkeeper
  module Models
    module Mongoid
      module Version
        def mongoid3?
          ::Mongoid::VERSION.starts_with?('3')
        end

        def mongoid4?
          ::Mongoid::VERSION.starts_with?('4')
        end
      end
    end
  end
end
