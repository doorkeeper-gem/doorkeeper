class Client
  include MongoMapper::Document
  safe
  timestamps!

  plugin DoorkeeperClient

  key :name,         String
  key :uid,          String
  key :secret,       String
  key :redirect_uri, String

  attr_accessible :name
end
