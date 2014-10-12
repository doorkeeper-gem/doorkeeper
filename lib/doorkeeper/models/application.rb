module Doorkeeper
  class Application
    include OAuth::Helpers
    include Models::Scopes
    alias_attribute :scopes, :valid_scopes
    
    has_many :access_grants, dependent: :destroy, class_name: 'Doorkeeper::AccessGrant'
    has_many :access_tokens, dependent: :destroy, class_name: 'Doorkeeper::AccessToken'

    validates :name, :secret, :uid, presence: true
    validates :uid, uniqueness: true
    validates :redirect_uri, redirect_uri: true
    validates :valid_scopes, presence: true, if: Proc.new {|p| p.respond_to?(:valid_scopes) && scope_required?}

    before_validation :generate_uid, :generate_secret, on: :create

    if ::Rails.version.to_i < 4 || defined?(ProtectedAttributes)
      attr_accessible :name, :redirect_uri, :valid_scopes, :scope_required
    end

    def self.by_uid_and_secret(uid, secret)
      where(uid: uid, secret: secret).first
    end

    def self.by_uid(uid)
      where(uid: uid).first
    end
    
    def scopes
      OAuth::Scopes.from_string(self.valid_scopes)
    end

    private

    def generate_uid
      self.uid ||= UniqueToken.generate
    end

    def generate_secret
      self.secret ||= UniqueToken.generate
    end
  end
end
