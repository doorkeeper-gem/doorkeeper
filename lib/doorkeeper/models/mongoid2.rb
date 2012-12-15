require 'doorkeeper/models/mongoid2/client'

module Doorkeeper
  module Models
    module Mongoid2
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Doorkeeper::Models::Mongoid2::Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, Association
        Doorkeeper::AccessGrant.send :include, Association
      end
    end
  end
end
