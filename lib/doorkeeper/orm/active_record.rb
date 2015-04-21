module Doorkeeper
  module Orm
    module ActiveRecord
      def self.initialize_models!
        require 'doorkeeper/orm/active_record/access_grant'
        require 'doorkeeper/orm/active_record/access_token'
        require 'doorkeeper/orm/active_record/application'

        if Doorkeeper.configuration.active_record_options[:establish_connection]
          [Doorkeeper::AccessGrant, Doorkeeper::AccessToken, Doorkeeper::Application].each do |c|
            c.send :establish_connection, Doorkeeper.configuration.active_record_options[:establish_connection]
          end
        end
      end

      def self.initialize_application_owner!
        require 'doorkeeper/models/concerns/ownership'

        Doorkeeper::Application.send :include, Doorkeeper::Models::Ownership
      end

      def self.check_requirements!(_config)
        if ::ActiveRecord::Base.connected? &&
           ::ActiveRecord::Base.connection.table_exists?(
             Doorkeeper::Application.table_name
           )
          unless Doorkeeper::Application.new.attributes.include?("scopes")
            fail <<-MSG.squish
[doorkeeper] Missing column: `oauth_applications.scopes`.
Run `rails generate doorkeeper:application_scopes
&& rake db:migrate` to add it.
            MSG
          end
        end
      end
    end
  end
end
