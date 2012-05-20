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
    end
  end
end
