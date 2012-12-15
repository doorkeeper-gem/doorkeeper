DatabaseCleaner[:mongoid].strategy = :truncation
DatabaseCleaner[:mongoid].clean_with :truncation

RSpec.configure do |config|
  config.before :suite do
    # Mongoid 2 and 3 have different ways of handling indexes
    if Doorkeeper.configuration.orm == :mongoid2
      Client.collection.drop_indexes
    elsif Doorkeeper.configuration.orm == :mongoid3
      Client.remove_indexes
    end

    Client.create_indexes

    Doorkeeper::AccessGrant.create_indexes
    Doorkeeper::AccessToken.create_indexes
  end
end
