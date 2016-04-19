module Doorkeeper
  module OAuth
    class PreAuthorization
      include PreAuthorizationMixin

      validate :response_type, error: :unsupported_response_type
      validate :redirect_uri, error: :invalid_redirect_uri

      attr_accessor :response_type, :state, :redirect_uri

      def initialize(server, client, attrs = {})
        @server        = server
        @client        = client
        @response_type = attrs[:response_type]
        @scope         = attrs[:scope]
        @redirect_uri  = attrs[:redirect_uri]
        @state         = attrs[:state]
      end

      private

      def validate_response_type
        server.authorization_response_types.include? response_type
      end

      # TODO: test uri should be matched against the client's one
      def validate_redirect_uri
        return false unless redirect_uri.present?
        Helpers::URIChecker.native_uri?(redirect_uri) ||
          Helpers::URIChecker.valid_for_authorization?(redirect_uri, client.redirect_uri)
      end
    end
  end
end
