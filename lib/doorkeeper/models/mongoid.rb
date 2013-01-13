require 'doorkeeper/models/mongoid/client'
require 'doorkeeper/models/mongoid/client_association'

module Doorkeeper
  module Models
    module Mongoid
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Doorkeeper::Models::Mongoid::Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, Doorkeeper::Models::Mongoid::ClientAssociation
        Doorkeeper::AccessGrant.send :include, Doorkeeper::Models::Mongoid::ClientAssociation
      end
    end
  end
end
