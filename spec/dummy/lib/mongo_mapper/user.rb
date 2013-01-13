class User
  include MongoMapper::Document
  timestamps!

  key :name,     String
  key :password, String

  attr_accessible :name, :password

  def self.authenticate!(name, password)
    User.where(:name => name, :password => password).first
  end
end
