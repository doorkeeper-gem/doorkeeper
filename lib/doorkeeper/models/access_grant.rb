module Doorkeeper
  class AccessGrant
    include Doorkeeper::OAuth::Helpers
    include Doorkeeper::Models::Expirable
    include Doorkeeper::Models::Revocable
    include Doorkeeper::Models::Accessible
    include Doorkeeper::Models::Scopes

    attr_accessible :resource_owner_id, :application_id, :expires_in, :redirect_uri, :scopes

    validates :resource_owner_id, :application_id, :token, :expires_in, :redirect_uri, :presence => true
    validates :token, :uniqueness => true

    before_validation :generate_token, :on => :create

    def self.authenticate(token)
      where(:token => token).first
    end

    private

    def generate_token
      self.token = UniqueToken.generate
    end
  end
end
