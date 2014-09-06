module Doorkeeper
  class Mongoid4Adapter
    def self.hook!
      require 'doorkeeper/orm_adapter/mongoid4/access_grant'
      require 'doorkeeper/orm_adapter/mongoid4/access_token'
      require 'doorkeeper/orm_adapter/mongoid4/application'
    end
  end
end
