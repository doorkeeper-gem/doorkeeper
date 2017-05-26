module Doorkeeper
  class User < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_users#{table_name_suffix}".to_sym

    include
  end
end