module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = :oauth_applications

    has_many :authorized_tokens, -> {where(:revoked_at => nil)}, :class_name => "AccessToken"
    has_many :authorized_applications, :through => :authorized_tokens, :source => :application

    def self.column_names_with_table
      self.column_names.map { |c| "#{self.table_name}.#{c}" }
    end

    def self.authorized_for(resource_owner)
      joins(:authorized_applications).
        where(:oauth_access_tokens => { :resource_owner_id => resource_owner.id, :revoked_at => nil }).
        group(column_names_with_table.join(','))
    end
  end
end
