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
        # authentication. The pattern tolerates the optional whitespace HTTP
        # allows around a field value (spaces and tabs only, RFC 9110 §5.6.3)
        # so a well-formed Bearer header is not misclassified, while a value
        # carrying a line break — never legal in a header — is not treated as
        # a bearer token. A bearer credential also carries at least one token
        # character after the scheme (RFC 6750 §2.1), so a scheme-only value
        # such as "Bearer " is not exempted either.
        def self.client_authentication_header?(request)
          header = request.authorization
          return false if header.blank?

          !header.match?(/\A[ \t]*Bearer[ \t]+\S/i)
        end
        private_class_method :client_authentication_header?

        def self.authenticate(request)
          params = request.request_parameters.with_indifferent_access

          Doorkeeper::ClientAuthentication::Credentials.new(params[:client_id], nil)
        end
      end
    end
  end
end
