module OAuth
  module Server
    class Authorization

      class InvalidRedirectionURI < StandardError; end

      attr_reader :application, :resource, :grant

      def initialize(application, resource, options = {})
        @application, @resource, @options = application, resource, options
      end

      def grant!
        validate_params!
        @grant ||= AccessGrant.create(
          application: application,
          resource: resource
        )
      end

      def redirect_uri
        uri = URI.parse(application.redirect_uri)
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
        options[:redirect_uri] == application.redirect_uri
      end
    end
  end
end
