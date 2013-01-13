module Doorkeeper
  module OAuth
    class TokenRequest
      def self.build(server)
        new(server.context.send(:pre_auth), server.current_resource_owner)
      end

      attr_accessor :pre_auth, :resource_owner, :client

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
          ErrorResponse.from_request pre_auth, :redirect_uri => pre_auth.redirect_uri, :response_on_fragment => true
        end
      end

      def deny
        pre_auth.error = :access_denied
        ErrorResponse.from_request(pre_auth, :redirect_uri => pre_auth.redirect_uri, :response_on_fragment => true)
      end
    end
  end
end
