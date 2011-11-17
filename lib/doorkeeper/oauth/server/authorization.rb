module OAuth
  module Server
    class Authorization

      class InvalidRedirectionURI < StandardError; end

      attr_reader :client, :resource, :grant

      def initialize(client, resource, options = {})
        @client, @resource, @options = client, resource, options
      end

      def grant!
        validate_params!
        @grant ||= AccessGrant.create(
          client: client,
          resource: resource
        )
      end

      def redirect_uri
        uri = URI.parse(client.redirect_uri)
        uri.query = "code=#{token}"
        uri.to_s
      end

      def token
        grant.code
      end

      private

      def options
        @options
      end

      def validate_params!
        raise InvalidRedirectionURI unless redirect_uri_valid?
      end

      def redirect_uri_valid?
        return true unless options[:redirect_uri].present?
        options[:redirect_uri] == client.redirect_uri
      end
    end
  end
end
