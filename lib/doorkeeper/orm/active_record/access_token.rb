module Doorkeeper
  class AccessToken < ActiveRecord::Base
    include AccessTokenMixin

    self.table_name = "#{table_name_prefix}oauth_access_tokens#{table_name_suffix}".to_sym

    def self.delete_all_for(application_id, resource_owner)
      where(application_id: application_id,
            resource_owner_id: resource_owner.id).delete_all
    end
    private_class_method :delete_all_for

    def self.order_method
      :order
    end

    def self.created_at_desc
      'created_at desc'
    end
  end
end
