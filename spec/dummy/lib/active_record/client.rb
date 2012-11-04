class Client < ActiveRecord::Base
  doorkeeper_client!

  attr_accessible :name
end
