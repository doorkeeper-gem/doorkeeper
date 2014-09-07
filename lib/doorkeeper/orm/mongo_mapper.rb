module Doorkeeper
  module Orm
    module MongoMapper
      def self.initialize_models!
        require 'doorkeeper/orm/mongo_mapper/access_grant'
        require 'doorkeeper/orm/mongo_mapper/access_token'
        require 'doorkeeper/orm/mongo_mapper/application'
      end
    end
  end
end
