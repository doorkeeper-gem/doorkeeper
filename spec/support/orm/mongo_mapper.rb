DatabaseCleaner[:mongo_mapper].strategy = :truncation
DatabaseCleaner[:mongo_mapper].clean_with :truncation

RSpec.configure do |config|
  config.before :suite do
    Doorkeeper::Application.create_indexes
    Doorkeeper::AccessGrant.create_indexes
    Doorkeeper::AccessToken.create_indexes
  end
end

module Doorkeeper
  class PlaceholderApplicationOwner
    include MongoMapper::Document

    set_collection_name 'placeholder_application_owners'
    many :applications, class: Doorkeeper::Application
  end

  module OrmHelper
    def mock_application_owner
      PlaceholderApplicationOwner.new
    end
  end
end
