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

      def self.initialize_table_names!
        [Doorkeeper::AccessGrant, Doorkeeper::AccessToken, Doorkeeper::Application].each do |model|
          entity = model.model_name.element # application, access_grant, access_token

          table_name = Doorkeeper.configuration.send("#{entity.pluralize}_table_name")
          fail "#{model} can't be initialized with blank table name!" if table_name.blank?

          model.table_name = table_name.to_sym
        end
      end

      def self.check_requirements!(_config)
        if ::ActiveRecord::Base.connected? &&
           ::ActiveRecord::Base.connection.table_exists?(
             Doorkeeper::Application.table_name
           )
          unless Doorkeeper::Application.new.attributes.include?("scopes")
            migration_path = '../../../generators/doorkeeper/templates/add_scopes_to_oauth_applications.rb'
            puts <<-MSG.squish
[doorkeeper] Missing column: `#{Doorkeeper::Application.table_name}.scopes`.
Create the following migration and run `rake db:migrate`.
            MSG
            puts File.read(File.expand_path(migration_path, __FILE__))
          end
        end
      end
    end
  end
end
