require 'doorkeeper/models/mongoid3/client'

module Doorkeeper
  module Models
    module Mongoid3
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Doorkeeper::Models::Mongoid3::Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, ClientAssociation
        Doorkeeper::AccessGrant.send :include, ClientAssociation
      end
    end
  end
end
