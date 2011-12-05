module Doorkeeper
  module Controller
    module ClassMethods
      def doorkeeper_for(*args, options)
        raise "You have to specify some option for doorkeeper_for method" unless options.present?

        filter_options = {}
        scopes = []
        if options.is_a? Hash
          scopes = options.delete(:scopes) || []
          filter_options = options.select { |k, v| [:except, :only].include? k }
        end

        filter_proc = proc do
          doorkeeper_before_filter(scopes)
        end

        before_filter filter_options, &filter_proc
      end
    end

    def self.included(base)
      base.extend ClassMethods
      base.send(:private, :doorkeeper_before_filter, :doorkeeper_token, :doorkeeper_valid_token, :get_doorkeeper_token)
    end

    def doorkeeper_before_filter(scopes = [])
      head :unauthorized unless doorkeeper_valid_token and doorkeeper_token_has_scope(scopes)
    end

    def doorkeeper_valid_token
      doorkeeper_token and doorkeeper_token.accessible?
    end

    def doorkeeper_token_has_scope(scopes)
      return true if scopes.empty?
      doorkeeper_token.scopes.any? { |scope| scopes.include? scope }
    end

    def doorkeeper_token
      @token ||= get_doorkeeper_token
    end

    def get_doorkeeper_token
      token = params[:access_token] || params[:bearer_token] || request.env['HTTP_AUTHORIZATION']
      if token
        token.gsub!(/Bearer /, '')
      end
      AccessToken.find_by_token(token)
    end
  end
end

ActionController::Base.send(:include, Doorkeeper::Controller)
