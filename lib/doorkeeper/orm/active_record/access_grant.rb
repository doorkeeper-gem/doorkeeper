module Doorkeeper
  class AccessGrant < ActiveRecord::Base
    self.table_name = Doorkeeper.configuration.access_grants_table_name.to_sym

    include AccessGrantMixin
  end
end
