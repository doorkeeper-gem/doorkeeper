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
          pattern = /^Bearer /i
          header  = request.authorization
          token_from_header(header, pattern) if match?(header, pattern)
        end

        def from_basic_authorization(request)
          pattern = /^Basic /i
          header  = request.authorization
          token_from_basic_header(header, pattern) if match?(header, pattern)
        end

        private

        def token_from_basic_header(header, pattern)
          encoded_header = token_from_header(header, pattern)
          token, _ = decode_basic_credentials(encoded_header)
          token
        end

        def decode_basic_credentials(encoded_header)
          Base64.decode64(encoded_header).split(/:/, 2)
        end

        def token_from_header(header, pattern)
          header.gsub pattern, ''
        end

        def match?(header, pattern)
          header && header.match(pattern)
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
        if token = from_request(request, *methods)
          access_token = AccessToken.by_token(token)
          access_token.revoke_previous_refresh_token! if access_token
          access_token
        end
      end
    end
  end
end
