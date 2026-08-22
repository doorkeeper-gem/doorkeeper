# frozen_string_literal: true

require "json"
require "uri"

module Doorkeeper
  module ClientIdMetadata
    # A parsed and validated Client ID Metadata Document (draft Section 4).
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
      # @raise [ValidationError] when the document violates Section 4
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

      # The draft sets no default for an omitted token_endpoint_auth_method,
      # and RFC 7591's (client_secret_basic) is a method Section 4.1 forbids
      # these clients, so the one method every such client can use is assumed.
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
      # itself to, carried over to the materialized application so that the
      # client is held to it. Only scopes this server configured are accepted
      # (validate_scope!): an application's own scopes *replace* the server's
      # as the allow-list rather than intersecting with them, so an unchecked
      # value here would let a document grant itself a scope the server never
      # defined instead of narrowing what it may ask for.
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

      # Section 4: the client_id property is required and must match the
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
      # of the document's contents are verified (draft Section 8.5), so it has
      # to be a plain string of a sane length rather than whatever JSON value
      # the document happens to carry there.
      def validate_client_name!
        name = attributes["client_name"]
        return if name.nil?

        raise ValidationError, "client_name must be a string" unless name.is_a?(String)

        raise ValidationError, "client_name is not valid UTF-8" unless valid_utf8?(name)
        return unless too_long?(name)

        raise ValidationError, "client_name is longer than #{MAX_PROPERTY_LENGTH} characters"
      end

      def too_long?(value)
        value.length > MAX_PROPERTY_LENGTH
      end

      # JSON.parse tags a response body's bytes as UTF-8 without checking that
      # they are, so a malformed sequence would reach the column this value is
      # written to (and the consent screen that renders it), or blow up in a
      # String method on the way — RedirectUriValidator splits the value, and
      # String#split raises on an invalid byte sequence. A NUL is valid UTF-8
      # but no text column takes it (PostgreSQL refuses it outright). Which
      # layer raises differs, so both are refused here instead.
      def valid_utf8?(value)
        value.encoding == Encoding::UTF_8 && value.valid_encoding? && !value.include?("\0")
      end

      # Section 4.1 in three layers: the draft's named shared-secret methods
      # are always rejected (whether or not this server knows them); the
      # method must then be one this server is configured to accept, so a
      # document cannot register itself with an auth method the token
      # endpoint would never be able to process; and the configured method
      # must not be secret-based, which each strategy declares through
      # +uses_shared_secret?+ (a strategy that declares nothing is treated as
      # secret-based — see ClientAuthentication::Method).
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

      # The document names the method by its IANA name, not by the key the
      # host application registered the strategy under (the two need not
      # match). Matching on the declared name is also what makes a strategy
      # that declares none unusable here: it answers nil, which no document
      # value equals, and Server would leave +authenticated_with+ nil for it
      # anyway, so such a document would materialize a client that could
      # never authenticate.
      def configured_auth_method(name)
        Doorkeeper.config.client_authentication_methods.detect do |method|
          method.auth_method_name == name
        end
      end

      # A document may legitimately omit redirect_uris (a client using only
      # grants that never redirect). Section 4.2 requires registered redirect
      # URIs for the ones that do, which materializing the application
      # enforces: a blank redirect_uri fails the model validation unless the
      # server's grant flows allow it, so such a client cannot start a
      # redirect-based flow.
      def validate_redirect_uris!
        uris = attributes["redirect_uris"]
        return if uris.nil?

        raise ValidationError, "redirect_uris must be an array of strings" unless uris.is_a?(Array) && uris.all?(String)
        return if uris.all? { |uri| valid_utf8?(uri) }

        raise ValidationError, "redirect_uris contains a URI that is not valid UTF-8"
      end

      # Beyond the type and length checks, the scopes named here must be ones
      # this server configured. The application row a document materializes
      # carries its own scopes, and ScopeChecker treats a client's scopes as
      # the allow-list in place of the server's (+app_scopes.presence ||
      # server_scopes+), so a document naming a scope the server never defined
      # would otherwise be issued a token for it — the check +enforce_configured_scopes+
      # performs on registered applications, which is off by default and whose
      # premise (an operator chose these scopes) does not hold for a document
      # the client writes itself.
      def validate_scope!
        value = attributes["scope"]
        return if value.nil?

        raise ValidationError, "scope must be a string" unless value.is_a?(String)
        raise ValidationError, "scope is not valid UTF-8" unless valid_utf8?(value)

        raise ValidationError, "scope is longer than #{MAX_PROPERTY_LENGTH} characters" if too_long?(value)
        return if value.empty? || configured_scopes?(value)

        raise ValidationError, "scope names scopes this authorization server does not configure"
      end

      def configured_scopes?(value)
        Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(
          scope_str: value,
          server_scopes: Doorkeeper.config.scopes,
        )
      end

      # The keys a client authenticates with come straight from the document,
      # so their container is type-checked here rather than deep inside the
      # authentication path. A document failing this is invalid and therefore
      # never cached (Section 5.2).
      def validate_jwks!
        uri = attributes["jwks_uri"]
        raise ValidationError, "jwks_uri must be a string" unless uri.nil? || uri.is_a?(String)

        # RFC 7591 Section 2: the two representations are mutually exclusive.
        # Rejecting the document is better than silently preferring one of
        # them, which would leave the server verifying against a key set the
        # client may not have meant to be authoritative.
        raise ValidationError, "jwks and jwks_uri must not both be present" if !uri.nil? && attributes.key?("jwks")

        set = attributes["jwks"]
        validate_private_key_jwt_keys!(uri, set)

        return if set.nil?

        unless set.is_a?(Hash) && set["keys"].is_a?(Array) && set["keys"].all?(Hash)
          raise ValidationError, "jwks must be a JSON object with a keys array of JSON objects"
        end

        validate_public_keys_only!(set["keys"])
      end

      # Section 4.1: "private key material MUST NOT be included in the Client
      # ID Metadata Document; only public keys, such as those published via
      # the jwks or jwks_uri properties, are permitted". A document carrying
      # its own private key has disclosed that credential to everyone who can
      # fetch the URL, and a symmetric key is the shared secret the same
      # section forbids establishing at all, so a document publishing either
      # is refused outright rather than left to authenticate with whatever
      # keys survive verification. A set fetched from jwks_uri is not part of
      # the document and so cannot be rejected with it; KeyResolver drops the
      # same key material there.
      def validate_public_keys_only!(keys)
        resolver = OAuth::ClientAuthentication::PrivateKeyJwt::KeyResolver
        return if keys.all? { |key| resolver.public_key?(key) }

        raise ValidationError, "jwks must publish public keys only"
      end

      # A document naming private_key_jwt as its auth method while publishing
      # no key its own jwks_uri could ever deliver describes a confidential
      # client that can never authenticate at the token endpoint, yet the
      # authorization endpoint would still materialize it and leave rows and
      # grants behind for it. No spec text requires the keys to be present
      # (RFC 7591 §2 lists jwks/jwks_uri as optional, and the draft states no
      # requirement on the value at all), so this is hygiene rather than
      # compliance — and it narrows the case rather than eliminating it: an
      # empty keys array or an unreachable https jwks_uri still validates. The
      # check is limited to private_key_jwt by name; other registered methods
      # define their own key discovery, and a document that names one of them
      # is not held to a jwks_uri it never authenticates with.
      def validate_private_key_jwt_keys!(uri, set)
        return unless token_endpoint_auth_method == "private_key_jwt"

        # A blank jwks_uri publishes no more keys than an absent one: it is
        # never fetched, so it must not satisfy this check either.
        raise ValidationError, "token_endpoint_auth_method private_key_jwt requires jwks or jwks_uri" if set.nil? && uri.blank?

        return if uri.blank? || fetchable_jwks_uri?(uri)

        raise ValidationError, "jwks_uri must be an https URL"
      end

      # The key fetcher accepts nothing but an https URL with a host (as does
      # the metadata document fetch itself, draft Section 3), so a jwks_uri
      # failing this is one no key will ever be read from — statically, not
      # because a server happens to be down. Rejecting it here keeps such a
      # document out of the cache instead of letting it stand until an
      # assertion is refused with a bare invalid_client.
      def fetchable_jwks_uri?(value)
        parsed = URI.parse(value)
        parsed.is_a?(URI::HTTPS) && parsed.host.present?
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
