module Doorkeeper
  module Rails
    class Routes
      class Mapping
        attr_accessor :controllers

        def initialize
          @controllers = {
            :authorization => 'doorkeeper/authorizations'
          }
        end
      end
    end
  end
end
