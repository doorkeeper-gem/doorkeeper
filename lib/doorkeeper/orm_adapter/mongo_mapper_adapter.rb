module Doorkeeper
  class MongoMapperAdapter
    def self.hook!
      require 'doorkeeper/orm_adapter/mongo_mapper/access_grant'
      require 'doorkeeper/orm_adapter/mongo_mapper/access_token'
      require 'doorkeeper/orm_adapter/mongo_mapper/application'
    end
  end
end
