require 'doorkeeper/oauth/client/credentials'

module Doorkeeper
  module OAuth
    class Client
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
