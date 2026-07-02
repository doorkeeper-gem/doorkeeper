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
      # contain URL-encodable characters.
      class ClientSecretBasic
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
