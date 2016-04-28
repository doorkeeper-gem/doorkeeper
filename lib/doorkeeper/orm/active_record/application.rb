module Doorkeeper
  class Application < ActiveRecord::Base
    self.table_name = "#{table_name_prefix}oauth_applications#{table_name_suffix}".to_sym

    include ApplicationMixin

    if ActiveRecord::VERSION::MAJOR >= 4
      has_many :authorized_tokens, -> { where(revoked_at: nil) }, class_name: 'AccessToken'
    else
      has_many :authorized_tokens, class_name: 'AccessToken', conditions: { revoked_at: nil }
    end
    has_many :authorized_applications, through: :authorized_tokens, source: :application

    def self.authorized_for(resource_owner)
      resource_access_tokens = AccessToken.active_for(resource_owner)
      where(id: resource_access_tokens.select(:application_id).distinct)
    end
  end
end
