module Doorkeeper
  module Helpers
    module Filter
      module ClassMethods
        def doorkeeper_for(*args)
          doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

          before_filter doorkeeper_for.filter_options do
            return if doorkeeper_for.validate_token(doorkeeper_token)
            # TODO: use ErrorRespose class for this
            render_options = doorkeeper_unauthorized_render_options
            if render_options.nil? || render_options.empty?
              head :unauthorized
            else
              render_options[:status] = :unauthorized
              render_options[:layout] = false if render_options[:layout].nil?
              render render_options
            end
          end
        end
      end

      def self.included(base)
        base.extend ClassMethods
        base.send :private, :doorkeeper_token, :doorkeeper_unauthorized_render_options
      end

      def doorkeeper_token
        methods = Doorkeeper.configuration.access_token_methods
        @token ||= OAuth::Token.authenticate request, *methods
      end

      def doorkeeper_unauthorized_render_options
        nil
      end
    end
  end
end
