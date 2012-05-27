module Doorkeeper
  module Helpers
    module Filter
      module ClassMethods
        def doorkeeper_for(*args)
          doorkeeper_for = DoorkeeperForBuilder.create_doorkeeper_for(*args)

          before_filter doorkeeper_for.filter_options do
            return if doorkeeper_for.validate_token(doorkeeper_token)
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
        base.send :private,
                  :doorkeeper_token,
                  :get_doorkeeper_token,
                  :authorization_bearer_token,
                  :doorkeeper_unauthorized_render_options
      end

      def doorkeeper_token
        @token ||= get_doorkeeper_token
      end

      def get_doorkeeper_token
        token = params[:access_token] || params[:bearer_token] || authorization_bearer_token
        if token
          AccessToken.find_by_token(token)
        end
      end

      def authorization_bearer_token
        header = request.env['HTTP_AUTHORIZATION']
        header.gsub(/^Bearer /, '') if header && header.match(/^Bearer /)
      end

      def doorkeeper_unauthorized_render_options
        nil
      end
    end
  end
end
