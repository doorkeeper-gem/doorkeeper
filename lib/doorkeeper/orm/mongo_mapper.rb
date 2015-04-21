module Doorkeeper
  module Orm
    module MongoMapper
      def self.initialize_models!
        require 'doorkeeper/orm/mongo_mapper/access_grant'
        require 'doorkeeper/orm/mongo_mapper/access_token'
        require 'doorkeeper/orm/mongo_mapper/application'
      end

      def self.initialize_application_owner!
        require 'doorkeeper/models/concerns/ownership'

        Doorkeeper::Application.send :include, Doorkeeper::Models::Ownership
      end

      def self.check_requirements!(_config); end
    end
  end
end
