module Doorkeeper
  class AccessGrant < Sequel::Model(:oauth_access_grants)
    include Doorkeeper::Models::SequelCompat
    include Doorkeeper::OAuth::Helpers
    include Doorkeeper::Models::Expirable
    include Doorkeeper::Models::Revocable
    include Doorkeeper::Models::Accessible
    include Doorkeeper::Models::Scopes

    # ---

    many_to_one :application, :class => "Doorkeeper::Application"

    if ::Rails.version.to_i < 4
      attr_accessible :resource_owner_id, :application_id, :expires_in, :redirect_uri, :scopes
    end

    plugin :validation_helpers
    def validate
      generate_token if new?
      super
      validates_presence [:resource_owner_id, :application_id, :token, :expires_in, :redirect_uri]
      validates_unique :token
    end

    def self.authenticate(token)
      where(:token => token).first
    end

    private

    def generate_token
      self.token = UniqueToken.generate
    end
  end
end
