module Doorkeeper
  class ApplicationController < ActionController::Base
    private

    def parse_client_info_from_basic_auth
      auth_header = request.env['HTTP_AUTHORIZATION']
      return unless auth_header && auth_header =~ /^Basic (.*)/m
      client_info = Base64.decode64($1).split(/:/, 2)
      client_id = client_info[0]
      client_secret = client_info[1]
      return if client_id.nil? || client_secret.nil?
      params[:client_id] = client_id
      params[:client_secret] = client_secret
    end

    def authenticate_resource_owner!
      current_resource_owner
    end

    def current_resource_owner
      instance_exec(main_app, &Doorkeeper.configuration.authenticate_resource_owner)
    end

    def authenticate_admin!
      if block = Doorkeeper.configuration.authenticate_admin
        instance_exec(main_app, &block)
      end
    end

    def method_missing(method, *args, &block)
      if method =~ /_(url|path)$/
        raise "Your path has not been found. Didn't you mean to call routes.#{method} in doorkeeper configuration blocks?"
      else
        super
      end
    end
  end
end
