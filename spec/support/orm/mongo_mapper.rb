DatabaseCleaner[:mongo_mapper].strategy = :truncation
DatabaseCleaner[:mongo_mapper].clean_with :truncation

RSpec.configure do |config|
  config.before :suite do
    Client.create_indexes
    Doorkeeper::AccessGrant.create_indexes
    Doorkeeper::AccessToken.create_indexes
  end
end
