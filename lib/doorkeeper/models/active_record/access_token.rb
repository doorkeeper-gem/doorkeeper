module Doorkeeper
  class AccessToken < ActiveRecord::Base
    self.table_name = :oauth_access_tokens
  end
end
