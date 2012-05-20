require 'doorkeeper/oauth/client/methods'

module Doorkeeper
  module OAuth
    class Client
      class Credentials < Struct.new(:uid, :secret)
        extend Methods

        def self.from_request(request, *methods)
          methods.inject(nil) do |credentials, method|
            credentials = Credentials.new *self.send(method, request)
            break credentials unless credentials.blank?
          end
        end

        def blank?
          uid.blank? || secret.blank?
        end
      end
    end
  end
end
