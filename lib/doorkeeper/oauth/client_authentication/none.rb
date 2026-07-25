# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3 "none": a public client that authenticates with only a
      # client_id and no secret (in the request body, not the query string).
      class None
        # Rejects a request that carries header-based client authentication (a
        # +Basic+ credential, or any non-blank Authorization header that is not
        # a bearer token): such a request must not be silently treated as an
        # unauthenticated public client. This is narrower than the legacy
        # +from_params+ extractor, which read the body +client_id+ regardless
        # of the Authorization header.
        #
        # A +Bearer+ Authorization header is the exception: it authorizes
        # access to the endpoint itself (e.g. a bearer-protected introspection
        # endpoint, RFC 7662 §2.1, or a revocation request) rather than
        # authenticating the client, so it must not suppress the +none+
        # strategy for a public client that identifies itself with a body
        # +client_id+.
        def self.matches_request?(request)
          params = request.request_parameters.with_indifferent_access

          request.post? &&
            !client_authentication_header?(request) &&
            params[:client_id].present? &&
            params[:client_secret].blank?
        end

        # A blank Authorization header carries no client authentication; a
        # bearer token authorizes the endpoint rather than the client. Every
        # other non-blank scheme (Basic, etc.) is header-based client
        # authentication.
        def self.client_authentication_header?(request)
          header = request.authorization
          return false if header.blank?

          !header.match?(/^Bearer /i)
        end

        def self.authenticate(request)
          params = request.request_parameters.with_indifferent_access

          Doorkeeper::ClientAuthentication::Credentials.new(params[:client_id], nil)
        end
      end
    end
  end
end
