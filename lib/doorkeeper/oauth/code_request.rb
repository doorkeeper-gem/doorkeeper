module Doorkeeper
  module OAuth
    class CodeRequest
      attr_accessor :pre_auth, :resource_owner, :client, :error

      def initialize(pre_auth, resource_owner)
        @pre_auth       = pre_auth
        @client         = pre_auth.client
        @resource_owner = resource_owner
      end

      def authorize
        @response = if pre_auth.authorizable?
          auth = Authorization::Code.new(pre_auth, resource_owner)
          auth.issue_token
          CodeResponse.new(pre_auth, auth)
        else
          ErrorResponse.from_request(self)
        end
      end

      def deny
        self.error = :access_denied
        ErrorResponse.from_request(self, :redirect_uri => pre_auth.redirect_uri)
      end

      # TODO: remove this, required for error response
      def state
        pre_auth.state
      end
    end
  end
end
