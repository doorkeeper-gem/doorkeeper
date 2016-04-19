module Doorkeeper
  class AccessGrant < ActiveRecord::Base
    self.table_name = Doorkeeper.configuration.access_grants_table_name

    include AccessGrantMixin
  end
end
