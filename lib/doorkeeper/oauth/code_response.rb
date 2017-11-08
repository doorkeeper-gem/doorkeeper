module Doorkeeper
  module OAuth
    class CodeResponse < BaseResponse
      include OAuth::Helpers

      attr_accessor :pre_auth, :auth, :response_on_fragment

      def initialize(pre_auth, auth, options = {})
        @pre_auth = pre_auth
        @auth = auth
        @response_on_fragment = options[:response_on_fragment]
      end

      def redirectable?
        true
      end

      def redirect_uri
        if URIChecker.native_uri? pre_auth.redirect_uri
          auth.native_redirect
        elsif response_on_fragment
          Authorization::URIBuilder.uri_with_fragment(
            pre_auth.redirect_uri,
            access_token: auth.token.token,
            token_type: auth.token.token_type,
            expires_in: auth.token.expires_in_seconds,
            state: pre_auth.state
          )
        else
          params = {
              code: auth.token.token,
              state: pre_auth.state,
          }
          # only include code_challenge info in the redirect if we have it
          if pre_auth.code_challenge.present?
            params[:code_challenge] = pre_auth.code_challenge
            params[:code_challenge_method] = pre_auth.code_challenge_method
          end
          Authorization::URIBuilder.uri_with_query(pre_auth.redirect_uri, params)
        end
      end
    end
  end
end
