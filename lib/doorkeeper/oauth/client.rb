require 'doorkeeper/oauth/client/methods'
require 'doorkeeper/oauth/client/credentials'

module Doorkeeper
  module OAuth
    class Client
      def self.find(uid, method = Application.method(:by_uid))
        if application = method.call(uid)
          new(application)
        end
      end

      def self.authenticate(credentials, method = Application.method(:authenticate))
        return false if credentials.blank?
        if application = method.call(credentials.uid, credentials.secret)
          new(application)
        end
      end

      delegate :id, :name, :uid, :redirect_uri, to: :@application

      def initialize(application)
        @application = application
      end

      attr_accessor :application
    end
  end
end
