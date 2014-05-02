# load schema to in memory sqlite
ActiveRecord::Migration.verbose = false
load Rails.root + 'db/schema.rb'

module Doorkeeper
  module OrmHelper
    def mock_application_owner
      mock_model 'User', id: 1234
    end
  end
end
