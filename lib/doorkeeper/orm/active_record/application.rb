module Doorkeeper
  class Application < ActiveRecord::Base
    include ApplicationMixin

    self.table_name = "#{table_name_prefix}oauth_applications#{table_name_suffix}".to_sym

    if ActiveRecord::VERSION::MAJOR >= 4
      has_many :authorized_tokens, -> { where(revoked_at: nil) }, class_name: 'AccessToken'
    else
      has_many :authorized_tokens, class_name: 'AccessToken', conditions: { revoked_at: nil }
    end
    has_many :authorized_applications, through: :authorized_tokens, source: :application

    def self.column_names_with_table
      self.column_names.map { |c| "#{table_name}.#{c}" }
    end

    def self.authorized_for(resource_owner)
      joins(:authorized_applications).
        where(AccessToken.table_name => { resource_owner_id: resource_owner.id, revoked_at: nil }).
        group(column_names_with_table.join(','))
    end
  end
end
