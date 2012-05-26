module Doorkeeper
  module Rails
    class Routes
      class Mapper
        def initialize(mapping = Mapping.new)
          @mapping = mapping
        end

        def map(&block)
          self.instance_eval(&block) if block
          @mapping
        end

        def controllers(controller_names = {})
          @mapping.controllers.merge!(controller_names)
        end
      end
    end
  end
end
