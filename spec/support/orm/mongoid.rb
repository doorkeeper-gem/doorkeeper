DatabaseCleaner[:mongoid].strategy = :truncation
DatabaseCleaner[:mongoid].clean_with :truncation

RSpec.configure do |config|
  config.before do
    Doorkeeper::Application.create_indexes
    Doorkeeper::AccessGrant.create_indexes
    Doorkeeper::AccessToken.create_indexes
  end
end

module Doorkeeper
  class PlaceholderApplicationOwner
    include Mongoid::Document

    if ::Mongoid::VERSION >= '3'
      self.store_in collection: :placeholder_application_owners
    else
      self.store_in :placeholder_application_owners
    end

    has_many :applications
  end

  module OrmHelper
    def mock_application_owner
      PlaceholderApplicationOwner.new
    end
  end
end
