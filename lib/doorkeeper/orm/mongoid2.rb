module Doorkeeper
  module Orm
    module Mongoid2
      def self.initialize_models!
        require 'doorkeeper/orm/mongoid2/access_grant'
        require 'doorkeeper/orm/mongoid2/access_token'
        require 'doorkeeper/orm/mongoid2/application'
      end
    end
  end
end
