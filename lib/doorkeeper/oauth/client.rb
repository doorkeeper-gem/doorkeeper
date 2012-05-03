module Doorkeeper
  module OAuth
    class Client
      class Credentials < Struct.new(:uid, :secret)
        def self.from_request(request)
          authorization = request.env['HTTP_AUTHORIZATION']
          params        = request.parameters
          if authorization.present? && authorization =~ /^Basic (.*)/m
            uid, secret = Base64.decode64($1).split(/:/, 2)
            new(uid, secret)
          else
            new(params[:client_id], params[:client_secret])
          end
        end

        def blank?
          uid.blank? || secret.blank?
        end
      end

      def self.find(uid)
        if application = Doorkeeper::Application.find_by_uid(uid)
          new(application)
        end
      end

      def self.authenticate(credentials, method = Doorkeeper::Application.method(:authenticate))
        return false if credentials.blank?
        if application = method.call(credentials.uid, credentials.secret)
          new(application)
        end
      end

      delegate :id, :name, :uid, :redirect_uri, :to => :@application

      def initialize(application)
        @application = application
      end
    end
  end
end
