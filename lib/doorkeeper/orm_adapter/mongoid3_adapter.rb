module Doorkeeper
  class Mongoid3Adapter
    def self.hook!
      require 'doorkeeper/orm_adapter/mongoid3/access_grant'
      require 'doorkeeper/orm_adapter/mongoid3/access_token'
      require 'doorkeeper/orm_adapter/mongoid3/application'
    end
  end
end
