module Doorkeeper
  module Rails
    module Helpers
      extend ActiveSupport::Concern

      def self.define_filter_method(scope)
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def doorkeeper_authorize_#{scope}!
            unless doorkeeper_token && doorkeeper_token.acceptable?('#{scope}')
              if !doorkeeper_token || !doorkeeper_token.accessible?
                error = OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
                options = doorkeeper_unauthorized_render_options
              else
                error = OAuth::ForbiddenTokenResponse.from_scope('#{scope}')
                options = doorkeeper_forbidden_render_options
              end

              headers.merge!(error.headers.reject { |k, v| ['Content-Type'].include? k })
              doorkeeper_render_error(error.status, options)
            end
          end
        METHODS
      end

      def doorkeeper_render_error(status, options = {})
        if options.blank?
          head status
        else
          options[:status] = status
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_token
        @_doorkeeper_token ||= OAuth::Token.authenticate request, *Doorkeeper.configuration.access_token_methods
      end

      def doorkeeper_unauthorized_render_options
        nil
      end

      def doorkeeper_forbidden_render_options
        nil
      end
    end
  end
end
