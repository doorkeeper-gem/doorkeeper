require 'doorkeeper/models/mongoid/client'

module Doorkeeper
  module Models
    module Mongoid
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Doorkeeper::Models::Mongoid::Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, ClientAssociation
        Doorkeeper::AccessGrant.send :include, ClientAssociation
      end
    end
  end
end
