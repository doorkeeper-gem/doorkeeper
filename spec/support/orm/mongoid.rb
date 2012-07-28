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

    self.store_in :placeholder_application_owners
    has_many :applications

  end

  module OrmHelper
  	def mock_application_owner
  		PlaceholderApplicationOwner.new
  	end
  end
end
