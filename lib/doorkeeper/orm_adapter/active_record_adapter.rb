module Doorkeeper
  class ActiveRecordAdapter
    def self.hook!
      require 'doorkeeper/orm_adapter/active_record/access_grant'
      require 'doorkeeper/orm_adapter/active_record/access_token'
      require 'doorkeeper/orm_adapter/active_record/application'
    end
  end
end
