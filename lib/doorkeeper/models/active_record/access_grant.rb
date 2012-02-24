module Doorkeeper
  class AccessGrant < ActiveRecord::Base
    self.table_name = :oauth_access_grants
  end
end
