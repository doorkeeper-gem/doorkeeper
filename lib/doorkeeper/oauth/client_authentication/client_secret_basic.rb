# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientAuthentication
      # RFC 6749 §2.3.1 "client_secret_basic": client credentials are sent
      # using HTTP Basic authentication.
      class ClientSecretBasic
        # Only match when the header actually decodes to a usable
        # +client_id+/+client_secret+ pair. A header that merely starts with
        # "Basic " but carries an empty or undecodable payload must not match,
        # otherwise it would shadow the other configured methods (e.g.
        # client_secret_post) even though +authenticate+ would return nil.
        def self.matches_request?(request)
          credentials_from(request).present?
        end

        def self.authenticate(request)
          client_id, client_secret = credentials_from(request)
          return unless client_id

          Doorkeeper::ClientAuthentication::Credentials.new(client_id, client_secret)
        end

        # Returns the decoded [client_id, client_secret] pair, or nil when the
        # request carries no usable HTTP Basic credentials.
        def self.credentials_from(request)
          authorization = request.authorization.to_s
          return unless authorization.downcase.start_with?("basic ")

          value = authorization.split(" ", 2).last
          client_id, client_secret = Base64.decode64(value.to_s).split(":", 2)
          return unless client_id.present? && client_secret.present?

          [client_id, client_secret]
        end
        private_class_method :credentials_from
      end
    end
  end
end
