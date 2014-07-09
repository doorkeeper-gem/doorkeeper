module Doorkeeper
  module Helpers
    module Filter
      module ClassMethods
        def doorkeeper_for(*args)
          doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

          before_filter doorkeeper_for.filter_options do
            unless doorkeeper_for.validate_token(doorkeeper_token)
              if !doorkeeper_token || !doorkeeper_token.accessible?
                @error = OAuth::InvalidTokenResponse.from_access_token(doorkeeper_token)
                error_status = :unauthorized
                options = doorkeeper_unauthorized_render_options
              else
                @error = OAuth::ForbiddenTokenResponse.from_scopes(doorkeeper_for.scopes)
                error_status = :forbidden
                options = doorkeeper_forbidden_render_options
              end
              headers.merge!(@error.headers.reject { |k, v| ['Content-Type'].include? k })
              render_error(error_status, options)
            end
          end
        end
      end

      def self.included(base)
        base.extend ClassMethods
        base.send :private, :doorkeeper_token, :doorkeeper_unauthorized_render_options
      end

      def doorkeeper_token
        return @token if instance_variable_defined?(:@token)
        methods = Doorkeeper.configuration.access_token_methods
        @token = OAuth::Token.authenticate request, *methods
      end

      def doorkeeper_unauthorized_render_options
        nil
      end

      def doorkeeper_forbidden_render_options
        nil
      end

      private

      def render_error(error, options)
        if options.blank?
          head error
        else
          options[:status] = error
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end
    end
  end
end
