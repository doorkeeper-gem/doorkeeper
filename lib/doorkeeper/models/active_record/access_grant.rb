module Doorkeeper
  class AccessGrant < ActiveRecord::Base
    if Doorkeeper.configuration.active_record_options[:establish_connection]
      establish_connection Doorkeeper.configuration.active_record_options[:establish_connection]
    end

    self.table_name = "#{self.table_name_prefix}oauth_access_grants".to_sym
  end
end
