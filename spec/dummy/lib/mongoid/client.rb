class Client
  include Mongoid::Document
  include Mongoid::Timestamps

  doorkeeper_client!

  field :name
  field :uid
  field :secret
  field :redirect_uri
end
