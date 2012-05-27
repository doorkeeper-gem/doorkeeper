module Doorkeeper
  module OAuth
    class Token
      module Methods
        def from_access_token_param(request)
          request.parameters[:access_token]
        end

        def from_bearer_param(request)
          request.parameters[:bearer_token]
        end

        def from_bearer_authorization(request)
          pattern = /^Bearer /
          header  = request.authorization
          header.gsub pattern, '' if header && header.match(pattern)
        end
      end

      extend Methods

      def self.from_request(request, *methods)
        methods.inject(nil) do |credentials, method|
          method = self.method(method) if method.is_a?(Symbol)
          credentials = method.call(request)
          break credentials unless credentials.blank?
        end
      end

      def self.authenticate(request, *methods)
        token = from_request request, *methods
        Doorkeeper::AccessToken.authenticate(token) if token
      end
    end
  end
end
