module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = :oauth_applications

    has_many :authorized_tokens, :class_name => "AccessToken", :conditions => { :revoked_at => nil }
    has_many :authorized_applications, :through => :authorized_tokens, :source => :application

    def self.column_names_with_table
      self.column_names.map { |c| "oauth_applications.#{c}" }
    end

    def self.authorized_for(resource_owner)
      joins(:authorized_applications).
        where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id, :revoked_at => nil }).
        group(column_names_with_table.join(','))
    end
  end
end
