# frozen_string_literal: true

require "json"

module Doorkeeper
  module ClientIdMetadata
    # A parsed and validated Client ID Metadata Document (draft Section 4.1).
    class Document
      # Shared symmetric secret authentication methods the draft forbids for
      # CIMD clients: no secret can have been established out of band.
      SHARED_SECRET_AUTH_METHODS = %w[
        client_secret_basic
        client_secret_post
        client_secret_jwt
      ].freeze

      # Properties that only make sense with a pre-established secret and are
      # therefore forbidden in a metadata document.
      FORBIDDEN_PROPERTIES = %w[
        client_secret
        client_secret_expires_at
      ].freeze

      PUBLIC_AUTH_METHOD = "none"

      # Properties copied into the application row's string columns, which the
      # generated migration declares as +t.string+ — 255 characters on MySQL.
      # An over-long value would surface as a database error while
      # materializing an otherwise valid-looking document, so the document is
      # rejected instead (UrlValidator::MAX_LENGTH does the same for the
      # client_id URL, which lands in the uid column).
      MAX_PROPERTY_LENGTH = 255

      ValidationError = Class.new(StandardError)

      attr_reader :client_id, :attributes

      # @param url [String] the client_id URL the document was fetched from
      # @param body [String] the raw response body
      # @raise [ValidationError] when the document violates Section 4.1
      def self.parse!(url, body)
        attributes = JSON.parse(body)
        raise ValidationError, "metadata document is not a JSON object" unless attributes.is_a?(Hash)

        new(url, attributes).tap(&:validate!)
      rescue JSON::ParserError => e
        raise ValidationError, "metadata document is not valid JSON: #{e.message}"
      end

      def initialize(client_id, attributes)
        @client_id = client_id
        @attributes = attributes
      end

      def validate!
        validate_client_id!
        validate_no_forbidden_properties!
        validate_client_name!
        validate_token_endpoint_auth_method!
        validate_redirect_uris!
        validate_scope!
        validate_jwks!
      end

      def token_endpoint_auth_method
        attributes.fetch("token_endpoint_auth_method", PUBLIC_AUTH_METHOD)
      end

      def confidential?
        token_endpoint_auth_method != PUBLIC_AUTH_METHOD
      end

      def redirect_uris
        Array(attributes["redirect_uris"])
      end

      def client_name
        attributes["client_name"]
      end

      # RFC 7591: a space-delimited list of the scopes the client restricts
      # itself to. Honouring it can only narrow what the client may ask for,
      # so it is carried over to the materialized application.
      def scope
        attributes["scope"]
      end

      def jwks
        attributes["jwks"]
      end

      def jwks_uri
        attributes["jwks_uri"]
      end

      private

      # Section 4.1: the client_id property is required and must match the
      # URL the document was fetched from using simple string comparison
      # (RFC 3986 Section 6.2.1).
      def validate_client_id!
        return if attributes["client_id"] == client_id

        raise ValidationError, "client_id property does not match the document URL"
      end

      def validate_no_forbidden_properties!
        present = FORBIDDEN_PROPERTIES.select { |property| attributes.key?(property) }
        return if present.empty?

        raise ValidationError, "forbidden properties present: #{present.join(", ")}"
      end

      # client_name is shown to the end user on the consent screen, and none
      # of the document's contents are verified (draft Section 6.4), so it has
      # to be a plain string of a sane length rather than whatever JSON value
      # the document happens to carry there.
      def validate_client_name!
        name = attributes["client_name"]
        return if name.nil?

        raise ValidationError, "client_name must be a string" unless name.is_a?(String)
        return if name.length <= MAX_PROPERTY_LENGTH

        raise ValidationError, "client_name is longer than #{MAX_PROPERTY_LENGTH} characters"
      end

      # Section 4.1 in three layers: the draft's named shared-secret methods
      # are always rejected (whether or not this server knows them); the
      # method must then be one this server is configured to accept, so a
      # document cannot register itself with an auth method the token
      # endpoint would never be able to process; and the configured method
      # must not be secret-based, which each strategy declares through
      # +uses_shared_secret?+ (with a conservative name-based fallback for
      # strategies that don't — see ClientAuthentication::Method).
      def validate_token_endpoint_auth_method!
        method = token_endpoint_auth_method

        unless method.is_a?(String) && SHARED_SECRET_AUTH_METHODS.exclude?(method)
          raise ValidationError, "token_endpoint_auth_method #{method.inspect} is not allowed " \
                                 "for client ID metadata documents"
        end

        configured = configured_auth_method(method)

        unless configured
          raise ValidationError, "token_endpoint_auth_method #{method.inspect} is not supported " \
                                 "by this authorization server"
        end

        return unless configured.uses_shared_secret?

        raise ValidationError, "token_endpoint_auth_method #{method.inspect} is not allowed " \
                               "for client ID metadata documents"
      end

      def configured_auth_method(name)
        Doorkeeper.config.client_authentication_methods.detect do |method|
          method.name.to_s == name
        end
      end

      # A document may legitimately omit redirect_uris (a client using only
      # grants that never redirect). Section 4.5 requires registered redirect
      # URIs for the ones that do, which materializing the application
      # enforces: a blank redirect_uri fails the model validation unless the
      # server's grant flows allow it, so such a client cannot start a
      # redirect-based flow.
      def validate_redirect_uris!
        uris = attributes["redirect_uris"]
        return if uris.nil?
        return if uris.is_a?(Array) && uris.all?(String)

        raise ValidationError, "redirect_uris must be an array of strings"
      end

      def validate_scope!
        value = attributes["scope"]
        return if value.nil?

        raise ValidationError, "scope must be a string" unless value.is_a?(String)
        return if value.length <= MAX_PROPERTY_LENGTH

        raise ValidationError, "scope is longer than #{MAX_PROPERTY_LENGTH} characters"
      end

      # The keys a client authenticates with come straight from the document,
      # so their container is type-checked here rather than deep inside the
      # authentication path. A document failing this is invalid and therefore
      # never cached (Section 4.4).
      def validate_jwks!
        uri = attributes["jwks_uri"]
        raise ValidationError, "jwks_uri must be a string" unless uri.nil? || uri.is_a?(String)

        # RFC 7591 Section 2: the two representations are mutually exclusive.
        # Rejecting the document is better than silently preferring one of
        # them, which would leave the server verifying against a key set the
        # client may not have meant to be authoritative.
        raise ValidationError, "jwks and jwks_uri must not both be present" if !uri.nil? && attributes.key?("jwks")

        set = attributes["jwks"]
        return if set.nil?
        return if set.is_a?(Hash) && set["keys"].is_a?(Array) && set["keys"].all?(Hash)

        raise ValidationError, "jwks must be a JSON object with a keys array of JSON objects"
      end
    end
  end
end
