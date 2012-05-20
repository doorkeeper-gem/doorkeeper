module Doorkeeper
  module OAuth
    class Client
      class Credentials < Struct.new(:uid, :secret)
        def self.from_request(request, *methods)
          methods.inject(nil) do |credentials, method|
            credentials = self.send method, request
            break credentials unless credentials.blank?
          end
        end

        def self.from_params(request)
          new *request.parameters.values_at(:client_id, :client_secret)
        end

        def self.from_basic(request)
          authorization = request.env['HTTP_AUTHORIZATION']
          if authorization.present? && authorization =~ /^Basic (.*)/m
            uid, secret = Base64.decode64($1).split(/:/, 2)
            new uid, secret
          end
        end

        def blank?
          uid.blank? || secret.blank?
        end
      end
    end
  end
end
