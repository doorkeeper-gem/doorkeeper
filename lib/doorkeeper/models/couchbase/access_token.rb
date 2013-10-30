module Doorkeeper
  class AccessToken < ::Couchbase::Model
    
    attribute :resource_owner_id, :token, :expires_at, :scopes
    attribute :created_at, :default => lambda { Time.now.to_i + 1 } # this does not need to be sub-second accurate
    view :by_resource_owner_id, :by_token, :by_refresh_token, :by_application_id_and_resource_owner_id

    alias_attribute :token, :id
    validates :application_id, :token, :presence => true

    before_create :generate_token
    before_create :generate_refresh_token, :if => :use_refresh_token?

    def expires_in
      30
    end

    def accessible?
      true if self.created_at + self.expires_in > Time.now.to_i
    end

    def self.authenticate(token)
      find(token)
    end

    def self.where_owner_id(id)
      Application.find(*by_resource_owner_id({:key => id}))
    end

    def self.by_refresh_token(refresh_token)
      by_refresh_token({:key => refresh_token})
    end

    def self.revoke_all_for(application_id, resource_owner)
      AccessToken.find(*by_application_id_and_resource_owner_id({:key => [application_id, resource_owner]})).delete
    end

    def self.matching_token_for(application, resource_owner_or_id, scopes)
      resource_owner_id = resource_owner_or_id.respond_to?(:to_key) ? resource_owner_or_id.id : resource_owner_or_id
      token = last_authorized_token_for(application, resource_owner_id).to_a[0]
      token if token && ScopeChecker.matches?(token.scopes, scopes)
    end

    def as_json(options={})
      {
        :resource_owner_id => self.resource_owner_id,
        :scopes => self.scopes,
        :expires_in_seconds => self.expires_at - Time.now,
        :application => { :uid => self.application.id }
      }
    end

    def scopes=(value) 
      self.attributes[:scopes] = value
    end

    def []= (key, value)
      self.attributes[key] = value
    end

    def [] (key)
      self.attributes[key]
    end

    def self.last_authorized_token_for(application, resource_owner_id)
      by_application_id_and_resource_owner_id({:key => [application.id, resource_owner_id], :stale => 'false'})
    end
    private_class_method :last_authorized_token_for

    def self.delete_all_for(application_id, resource_owner)
      where(:application_id => application_id,
            :resource_owner_id => resource_owner.id).delete_all
    end
    private_class_method :delete_all_for 

    private

    def generate_refresh_token
      if use_refresh_token
        self.refresh_token = UniqueToken.generate
      end
    end

    def generate_token
      self.id = UniqueToken.generate
    end
    

  end
end
