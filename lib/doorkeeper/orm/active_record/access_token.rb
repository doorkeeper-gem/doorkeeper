module Doorkeeper
  class AccessToken < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_access_tokens#{table_name_suffix}".to_sym

    include AccessTokenMixin

    def self.delete_all_for(application_id, resource_owner)
      where(application_id: application_id,
            resource_owner_id: resource_owner.id).delete_all
    end
    private_class_method :delete_all_for

    def self.for(resource_owner)
      where(resource_owner_id: resource_owner.id, revoked_at: nil)
    end

    def self.order_method
      :order
    end

    def self.refresh_token_revoked_on_use?
      column_names.include?('previous_refresh_token')
    end

    def self.created_at_desc
      'created_at desc'
    end
  end
end
