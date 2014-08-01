module Doorkeeper
  module Rails
    module Helpers
      extend ActiveSupport::Concern

      DOORKEEPER_BEARER_PREFIX = 'doorkeeper_bearer_for'

      module ClassMethods
        def doorkeeper_for(*args)
          doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

          filter_name = :"#{DOORKEEPER_BEARER_PREFIX}_#{doorkeeper_for.name}"

          send :define_method, filter_name do
            unless valid_token?(doorkeeper_for.scopes)
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

          protected filter_name

          prepend_before_filter filter_name, doorkeeper_for.filter_options
        end

        def skip_doorkeeper_for(*actions)
          doorkeeper_bearers = protected_instance_methods.grep(/#{DOORKEEPER_BEARER_PREFIX}/)
          options = actions.extract_options!

          actions.each do |action|
            if action == :all
              skip_before_filter *doorkeeper_bearers.grep(/all/), options
            else
              specified_bearers = doorkeeper_bearers.grep(/#{action}/).reject do |bearer_name|
                tuple = bearer_name.to_s.split('_')
                tuple.index('except') < tuple.index(action.to_s)
              end

              if specified_bearers.empty?
                skip_before_filter *doorkeeper_bearers.grep(/all/), only: action
              else
                skip_before_filter *specified_bearers
              end
            end
          end
        end
      end

      private

      def valid_token?(scopes)
        doorkeeper_token && doorkeeper_token.acceptable?(scopes)
      end

      def render_error(error, options)
        if options.blank?
          head error
        else
          options[:status] = error
          options[:layout] = false if options[:layout].nil?
          render options
        end
      end

      def doorkeeper_token
        @token ||= OAuth::Token.authenticate request, *config_methods
      end

      def config_methods
        @methods ||= Doorkeeper.configuration.access_token_methods
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
