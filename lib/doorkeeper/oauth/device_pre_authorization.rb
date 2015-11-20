module Doorkeeper
  module OAuth
    class DevicePreAuthorization
      include PreAuthorizationMixin

      def initialize(server, client, attrs = {})
        @server = server
        @client = client
        @scope  = attrs[:scope]
      end
    end
  end
end
