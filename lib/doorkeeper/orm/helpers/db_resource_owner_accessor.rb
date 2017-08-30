module Doorkeeper
  module Orm
    module Helpers
      module DbResourceOwnerAccessor
        def self.get_by_id(resource_owner_id)
          User.find_by_id(resource_owner_id)
        end
      end
    end
  end
end
