module Doorkeeper
  module Rails
    module Helpers
      extend ActiveSupport::Concern

      module ClassMethods
        def doorkeeper_for(*args, &block)
          fail Errors::DoorkeeperError, "`doorkeeper_for` no longer available", <<-eos
\nStarting in version 2.0.0 of doorkeeper gem, `doorkeeper_for` is no longer
available. Please change `doorkeeper_for` calls in your application with:

  before_action :doorkeeper_authorize!

For more information check the README:
https://github.com/doorkeeper-gem/doorkeeper#protecting-resources-with-oauth-aka-your-api-endpoint\n
          eos
        end
      end

      def doorkeeper_token
        @_doorkeeper_token ||= OAuth::Token.authenticate request, *Doorkeeper.configuration.access_token_methods
      end

      def valid_doorkeeper_token?(*scopes)
        doorkeeper_token && doorkeeper_token.acceptable?(scopes)
      end

      def doorkeeper_authorize!(*scopes)
        scopes ||= Doorkeeper.configuration.default_scopes

        unless valid_doorkeeper_token?(*scopes)
          if !doorkeeper_token || !doorkeeper_token.accessible?
            error = OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
            options = doorkeeper_unauthorized_render_options
          else
            error = OAuth::ForbiddenTokenResponse.from_scopes(scopes)
            options = doorkeeper_forbidden_render_options
          end
          headers.merge!(error.headers.reject { |k| ['Content-Type'].include? k })
          doorkeeper_error_renderer(error, options)
        end
      end

      def doorkeeper_unauthorized_render_options
        nil
      end

      def doorkeeper_forbidden_render_options
        nil
      end

      def doorkeeper_error_renderer(error, options = {})
        if options.blank?
          head error.status
        else
          options[:status] = error.status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end
    end
  end
end
