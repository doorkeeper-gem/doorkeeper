module Doorkeeper
  module OAuth
    class Client
      module Methods
        def from_params(request)
          request.parameters.values_at(:client_id, :client_secret)
        end

        def from_basic(request)
          authorization = request.authorization
          if authorization.present? && authorization =~ /^Basic (.*)/m
            Base64.decode64($1).split(/:/, 2)
          end
        end
      end
    end
  end
end
