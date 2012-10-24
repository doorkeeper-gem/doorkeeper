module Doorkeeper
  module OAuth
    class TokenRequest
      attr_accessor :pre_auth, :resource_owner, :client, :error

      def initialize(pre_auth, resource_owner)
        @pre_auth       = pre_auth
        @client         = pre_auth.client
        @resource_owner = resource_owner
      end

      def authorize
        @response = if pre_auth.authorizable?
          auth = Authorization::Token.new(pre_auth, resource_owner)
          auth.issue_token
          CodeResponse.new pre_auth, auth, :response_on_fragment => true
        else
          ErrorResponse.from_request self, :redirect_uri => pre_auth.redirect_uri, :response_on_fragment => true
        end
      end

      def deny
        self.error = :access_denied
        ErrorResponse.from_request(self, :redirect_uri => pre_auth.redirect_uri, :response_on_fragment => true)
      end

      # TODO: remove this, required for error response
      def state
        pre_auth.state
      end
    end
  end
end
