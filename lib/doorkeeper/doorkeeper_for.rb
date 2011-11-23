module Doorkeeper
  module Controller
    module ClassMethods
      def doorkeeper_for(options)
        raise "You have to specify some option for doorkeeper_for method" unless options.present?
        options = nil if options == :all
        if options
          before_filter :doorkeeper_before_filter, options
        else
          before_filter :doorkeeper_before_filter
        end
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send(:private, :doorkeeper_before_filter, :doorkeeper_token, :doorkeeper_valid_token, :get_doorkeeper_token)
    end

    def doorkeeper_before_filter
      head :unauthorized unless doorkeeper_valid_token
    end

    def doorkeeper_valid_token
      doorkeeper_token and doorkeeper_token.accessible?
    end

    def doorkeeper_token
      @token ||= get_doorkeeper_token
    end

    def get_doorkeeper_token
      token = params[:access_token] || params[:bearer_token] || request.env['Authorization']
      if token
        token.gsub!(/Bearer /, '')
      end
      AccessToken.find_by_token(token)
    end
  end
end

ActionController::Base.send(:include, Doorkeeper::Controller)
