module Doorkeeper
  module Rails
    module Helpers
      extend ActiveSupport::Concern

      def doorkeeper_authorize!(*scopes)
        @_doorkeeper_scopes = scopes || Doorkeeper.configuration.default_scopes

        if doorkeeper_token_is_invalid?
          doorkeeper_render_error
        end
      end

      def doorkeeper_unauthorized_render_options
        nil
      end

      def doorkeeper_forbidden_render_options
        nil
      end

      private

      def doorkeeper_token_is_invalid?
        !doorkeeper_token || !doorkeeper_token.acceptable?(@_doorkeeper_scopes)
      end

      def doorkeeper_render_error
        error = doorkeeper_error
        headers.merge! error.headers.reject { |k| "Content-Type" == k }
        doorkeeper_render_error_with(error)
      end

      def doorkeeper_render_error_with(error)
        options = doorkeeper_render_options || {}
        if options.blank?
          head error.status
        else
          options[:status] = error.status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_error
        if doorkeeper_invalid_token_response?
          OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
        else
          OAuth::ForbiddenTokenResponse.from_scopes(@_doorkeeper_scopes)
        end
      end

      def doorkeeper_render_options
        if doorkeeper_invalid_token_response?
          doorkeeper_unauthorized_render_options
        else
          doorkeeper_forbidden_render_options
        end
      end

      def doorkeeper_invalid_token_response?
        !doorkeeper_token || !doorkeeper_token.accessible?
      end

      def doorkeeper_token
        @_doorkeeper_token ||= OAuth::Token.authenticate(
          request,
          *Doorkeeper.configuration.access_token_methods
        )
      end

      module ClassMethods
        def doorkeeper_for(*_args)
          fail(
            Errors::DoorkeeperError,
            "`doorkeeper_for` no longer available",
            <<-eos
\nStarting in version 2.0.0 of doorkeeper gem, `doorkeeper_for` is no longer
available. Please change `doorkeeper_for` calls in your application with:

  before_action :doorkeeper_authorize!

For more information check the README:
https://github.com/doorkeeper-gem/doorkeeper#protecting-resources-with-oauth-aka-your-api-endpoint\n
eos
          )
        end
      end
    end
  end
end
