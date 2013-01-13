class Client
  include Mongoid::Document
  include Mongoid::Timestamps

  doorkeeper_client!

  field :name
  field :uid
  field :secret
  field :redirect_uri

  attr_accessible :name, :redirect_uri

  index({ uid: 1 }, { unique: true })
end
