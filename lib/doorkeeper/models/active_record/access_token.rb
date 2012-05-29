module Doorkeeper
  class AccessToken < ActiveRecord::Base
    self.table_name = :oauth_access_tokens

    def self.last_authorized_token_for(application, resource_owner_id)
      accessible.
        where(:application_id => application.id,
              :resource_owner_id => resource_owner_id).
        order('created_at desc').
        limit(1).
        first
    end
    private_class_method :last_authorized_token_for
  end
end
