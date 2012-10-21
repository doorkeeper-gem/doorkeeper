module Doorkeeper
  module Helpers
    module Controller
      def self.included(base)
        base.send :private,
                  :authenticate_resource_owner!,
                  :authenticate_admin!,
                  :current_resource_owner,
                  :resource_owner_from_credentials,
                  :skip_authorization?
      end

      def authenticate_resource_owner!
        current_resource_owner
      end

      def current_resource_owner
        instance_eval &Doorkeeper.configuration.authenticate_resource_owner
      end

      def resource_owner_from_credentials
        instance_eval &Doorkeeper.configuration.resource_owner_from_credentials
      end

      def authenticate_admin!
        instance_eval &Doorkeeper.configuration.authenticate_admin
      end
      
      def skip_authorization?
         Doorkeeper.configuration.skip_authorization
      end
    end
  end
end
