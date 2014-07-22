module Doorkeeper
  class AccessToken < ActiveRecord::Base
    if Doorkeeper.configuration.active_record_options[:establish_connection]
      establish_connection Doorkeeper.configuration.active_record_options[:establish_connection]
    end

    self.table_name = "#{table_name_prefix}oauth_access_tokens#{table_name_suffix}".to_sym

    def self.delete_all_for(application_id, resource_owner)
      where(application_id: application_id,
            resource_owner_id: resource_owner.id).delete_all
    end
    private_class_method :delete_all_for

    def self.last_authorized_token_for(application_id, resource_owner_id)
      where(application_id: application_id,
            resource_owner_id: resource_owner_id,
            revoked_at: nil).
        order('created_at desc').
        limit(1).
        first
    end
    private_class_method :last_authorized_token_for
  end
end
