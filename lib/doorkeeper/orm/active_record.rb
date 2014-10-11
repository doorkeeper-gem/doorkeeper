module Doorkeeper
  module Orm
    module ActiveRecord
      def self.initialize_models!
        require 'doorkeeper/orm/active_record/access_grant'
        require 'doorkeeper/orm/active_record/access_token'
        require 'doorkeeper/orm/active_record/application'

        if Doorkeeper.configuration.active_record_options[:establish_connection]
          [Doorkeeper::AccessGrant, Doorkeeper::Application, Doorkeeper::AccessGrant].each do |c|
            c.send :establish_connection, Doorkeeper.configuration.active_record_options[:establish_connection]
          end
        end
      end
    end
  end
end
