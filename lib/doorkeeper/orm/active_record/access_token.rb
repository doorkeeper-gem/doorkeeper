module Doorkeeper
  class AccessToken < ActiveRecord::Base
    self.table_name = Doorkeeper.configuration.access_tokens_table_name.to_sym

    include AccessTokenMixin

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
