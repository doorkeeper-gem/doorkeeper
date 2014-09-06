module Doorkeeper
  class Mongoid2Adapter
    def self.hook!
      require 'doorkeeper/orm_adapter/mongoid2/access_grant'
      require 'doorkeeper/orm_adapter/mongoid2/access_token'
      require 'doorkeeper/orm_adapter/mongoid2/application'
    end
  end
end
