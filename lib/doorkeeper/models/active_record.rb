require 'doorkeeper/models/active_record/client'

module Doorkeeper
  module Models
    module ActiveRecord
      def doorkeeper_client!(options = {})
        Doorkeeper.client = self
        include Client
        include Doorkeeper::Models::Registerable
        include Doorkeeper::Models::Authenticatable
        Doorkeeper::AccessToken.send :include, Association
        Doorkeeper::AccessGrant.send :include, Association
      end
    end
  end
end
