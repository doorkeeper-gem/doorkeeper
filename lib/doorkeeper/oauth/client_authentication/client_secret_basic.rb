# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3.1 "client_secret_basic": client credentials are sent
      # using HTTP Basic authentication.
      #
      # Known deviation: §2.3.1 also requires the client_id and client_secret
      # to be form-urlencoded before being placed into the Basic header.
      # Doorkeeper has never URL-decoded them (like much of the ecosystem),
      # and this strategy deliberately keeps that behaviour — adding the
      # decoding now would break every existing client whose credentials
      # contain URL-encodable characters. A consequence worth naming: a
      # client whose uid contains a ":" cannot authenticate this way at all,
      # since the credential is split at the first one and the encoded form
      # is never decoded back. Doorkeeper-generated uids never contain one,
      # but a Client Identifier URL always does; such a client uses
      # client_secret_post, or a method that needs no shared secret.
      class ClientSecretBasic
        def self.uses_shared_secret?
          true
        end

        # The IANA token endpoint authentication method name this
        # implements — see Credentials#authenticated_with.
        AUTH_METHOD_NAME = "client_secret_basic"

        def self.auth_method_name
          AUTH_METHOD_NAME
        end

        # Match whenever the header decodes to a non-blank +client_id+ — i.e.
        # whenever a Basic authentication *attempt* is present. The secret may
        # be empty (public clients) or missing; those are still Basic auth
        # attempts and must be claimed here so that invalid credentials fail
        # with +invalid_client+ instead of silently falling through to another
        # configured method or the fallback (which would downgrade a failed
        # authentication attempt to "no authentication provided").
        def self.matches_request?(request)
          credentials_from(request).present?
        end

        def self.authenticate(request)
          client_id, client_secret = credentials_from(request)
          return unless client_id

          # RFC 7521 §4.2: a client_id parameter sent alongside another
          # authentication method must agree with the identity that method
          # establishes — the same check PrivateKeyJwt applies to an
          # assertion's issuer. A request carrying credentials for one client
          # and a client_id naming another presents two client identities and
          # authenticates neither: without this it would be authenticated as
          # the Basic client while the body asked to act as a different one,
          # with nothing signalling the mismatch. A bare client_id is not an
          # authentication method of its own, so +validate_client_authentication!+
          # deliberately doesn't count it and cannot catch this.
          request_client_id = request.request_parameters["client_id"] || request.request_parameters[:client_id]
          return if request_client_id.present? && request_client_id != client_id

          Doorkeeper::ClientAuthentication::Credentials.new(client_id, client_secret)
        end

        # Returns the decoded [client_id, client_secret] pair, or nil when the
        # request carries no HTTP Basic +client_id+. A header that merely
        # starts with "Basic " but decodes to an empty/blank client_id (e.g.
        # an empty payload or a leading ":") is not a usable attempt and does
        # not match.
        def self.credentials_from(request)
          authorization = request.authorization.to_s
          return unless authorization.downcase.start_with?("basic ")

          value = authorization.split(" ", 2).last
          client_id, client_secret = Base64.decode64(value.to_s).split(":", 2)
          return if client_id.blank?

          [client_id, client_secret]
        end
        private_class_method :credentials_from
      end
    end
  end
end
