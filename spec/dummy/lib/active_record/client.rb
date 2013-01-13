class Client < ActiveRecord::Base
  doorkeeper_client!

  attr_accessible :name, :redirect_uri
end
