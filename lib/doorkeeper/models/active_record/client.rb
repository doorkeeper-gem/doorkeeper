module Doorkeeper
  module Models
    module ActiveRecord
      module Client
        extend ActiveSupport::Concern

        included do
          has_many :authorized_tokens, :class_name => "Doorkeeper::AccessToken", :conditions => { :revoked_at => nil }, :foreign_key => 'application_id'
          has_many :authorized_applications, :through => :authorized_tokens, :source => :application
        end

        module ClassMethods
          def column_names_with_table
            self.column_names.map { |c| "clients.#{c}" }
          end

          # TODO: Authorized tokens should not be mixed in into client's class
          def authorized_for(resource_owner)
            joins(:authorized_applications).
              where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id, :revoked_at => nil }).
              group(column_names_with_table.join(','))
          end
        end
      end

      module Association
        extend ActiveSupport::Concern

        included do
          belongs_to :application, :class_name => "::#{Doorkeeper.client}", :foreign_key => 'application_id'
        end
      end
    end
  end
end
