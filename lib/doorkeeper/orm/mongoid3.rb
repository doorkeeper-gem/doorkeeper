module Doorkeeper
  module Orm
    module Mongoid3
      def self.initialize_models!
        require 'doorkeeper/orm/mongoid3/access_grant'
        require 'doorkeeper/orm/mongoid3/access_token'
        require 'doorkeeper/orm/mongoid3/application'
      end

      def self.initialize_application_owner!
        require 'doorkeeper/models/concerns/ownership'

        Doorkeeper::Application.send :include, Doorkeeper::Models::Ownership
      end
    end
  end
end
