module Doorkeeper
  class Application < Sequel::Model(:oauth_applications)
    include Doorkeeper::Models::SequelCompat
    include Doorkeeper::OAuth::Helpers

    one_to_many :authorized_tokens, conditions: { revoked_at: nil }, :class => "Doorkeeper::AccessToken"

    def self.authorized_for(resource_owner)
      AccessToken.where(:resource_owner_id => resource_owner.id, :revoked_at => nil).map(&:application)
    end

    # ---

    one_to_many :access_grants, :class => "Doorkeeper::AccessGrant"
    one_to_many :access_tokens, :class => "Doorkeeper::AccessToken"
    plugin :association_dependencies, access_grants: :destroy, access_tokens: :destroy

    plugin :validation_helpers
    def validate
      if new?
        generate_uid
        generate_secret
      end
      super
      validates_presence [:name, :secret, :uid, :redirect_uri]
      validates_unique :uid
      RedirectUriValidator.new(attributes: values).validate_each(self, :redirect_uri, redirect_uri)
    end

    if ::Rails.version.to_i < 4
      attr_accessible :name, :redirect_uri
    end

    def self.model_name
      ActiveModel::Name.new(self, Doorkeeper, 'Application')
    end

    def self.authenticate(uid, secret)
      self.where(:uid => uid, :secret => secret).first
    end

    def self.by_uid(uid)
      self.where(:uid => uid).first
    end

    private

    def generate_uid
      self.uid = UniqueToken.generate
    end

    def generate_secret
      self.secret = UniqueToken.generate
    end
  end
end
