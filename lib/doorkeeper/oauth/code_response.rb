module Doorkeeper
  module OAuth
    class CodeResponse
      include Doorkeeper::OAuth::Authorization::URIBuilder
      include Doorkeeper::OAuth::Helpers

      attr_accessor :pre_auth, :auth, :response_on_fragment

      def initialize(pre_auth, auth, options = {})
        @pre_auth, @auth      = pre_auth, auth
        @response_on_fragment = options[:response_on_fragment]
      end

      def redirectable?
        !URIChecker.native_uri?(pre_auth.redirect_uri)
      end

      # TODO: configure the test oauth path?
      def redirect_uri
        if URIChecker.test_uri? pre_auth.redirect_uri
          "/oauth/authorize/#{auth.token.token}"
        else
          if response_on_fragment
            # TODO: bugged here, auth.token has no token_type field, so it will raise undefined method error
            uri_with_fragment(pre_auth.redirect_uri, {
              :access_token => auth.token.token,
              :token_type   => auth.token.token_type,
              :expires_in   => auth.token.expires_in,
              :state        => pre_auth.state
            })
          else
            uri_with_query pre_auth.redirect_uri, :code => auth.token.token, :state => pre_auth.state
          end
        end
      end

      def body
        {
            'grant_token' => auth.token.token,
            'token_type'  => 'authorization_code',
            'expires_in'  => auth.token.expires_in
        }.reject { |_, value| value.blank? }
      end

      def status
        :ok
      end

      def headers
        { 'Cache-Control' => 'no-store', 'Pragma' => 'no-cache', 'Content-Type' => 'application/json; charset=utf-8' }
      end
    end
  end
end
