require 'doorkeeper/models/active_record/client'

module Doorkeeper
  module Models
    module ActiveRecord
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Doorkeeper::Models::ActiveRecord::Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, ClientAssociation
        Doorkeeper::AccessGrant.send :include, ClientAssociation
      end
    end
  end
end
