# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # OAuth Client ID Metadata Documents (draft-ietf-oauth-client-id-metadata-document)
    # for public clients: an https client_id is the URL of the client's own metadata,
    # fetched and kept as an application row, since grants and tokens reference one.
    #
    # Rows written from a document carry the time of the first write in MARKER, which is what tells
    # them apart from registered applications (draft-03, Supporting Both Pre-Registered and
    # Unregistered Clients). ActiveRecord only.
    module ClientIdMetadataDocument
      MARKER = :client_id_metadata_materialized_at

      # A refused client_id is looked up like a registered one, so its document is never fetched. Neither is
      # the issuer's own, as its tokens' aud and its assertions' iss would then name this server
      # (draft-03, Client Identifier URL Confusion Attacks); other parties' identifiers are for
      # allow_client_id_metadata_document to refuse.
      def self.url?(client_id)
        Doorkeeper.config.use_client_id_metadata_documents? && url_form?(client_id) &&
          client_id.to_s != Doorkeeper.config.issuer.to_s && allowed?(client_id)
      end

      # The port is held to what the fetcher could connect to, so the two agree on what is fetchable.
      def self.url_form?(client_id)
        return false unless storable?(client_id.to_s)

        uri = URI.parse(client_id.to_s)
        uri.is_a?(URI::HTTPS) && uri.host.present? && HttpFetcher::PORT_RANGE.cover?(uri.port) &&
          uri.path.length > 1 && uri.userinfo.nil? && uri.fragment.nil? &&
          (uri.path.split("/").map { |segment| URI.decode_uri_component(segment) } & %w[. ..]).empty?
      rescue URI::InvalidURIError, ArgumentError
        false
      end

      # At most 255 characters, as the uid column holds no more on MySQL, and no control characters,
      # which URI.parse lets through in a query, and which would reach the log on a refusal.
      def self.storable?(client_id)
        client_id.length <= 255 && !client_id.match?(/[[:cntrl:]]/)
      end

      def self.materialized?(application)
        application.respond_to?(MARKER) && application.public_send(MARKER).present?
      end

      # A row written from a document while the option was on, and is no longer, or whose
      # client_id is refused by now.
      def self.orphaned?(application)
        materialized?(application) && !url?(application.uid)
      end

      def self.allowed?(client_id)
        Doorkeeper.config.allow_client_id_metadata_document.call(client_id)
      end

      # A row written from a document stands for one client_id only, compared as a simple string
      # (draft-03, Client Identifier URL). The database may compare more loosely: MySQL's default
      # collations ignore case and accents, some of them trailing spaces as well.
      def self.other_client?(application, client_id)
        materialized?(application) && application.uid != client_id.to_s
      end

      # The authorization endpoint's lookup. A registered application wins (draft-03, Pre-Registering
      # Client Identifier URLs); otherwise the document is fetched, and a failed fetch refuses the
      # client even when a row was written from an earlier one (draft-03, Metadata Discovery Errors).
      def self.application(client_id)
        model = Doorkeeper.config.application_model
        registered = model.by_uid(client_id)
        return registered if registered && !materialized?(registered)
        return if other_client?(registered, client_id)

        entry = cache.fetch(client_id) { (document = fetch(client_id)) && { document: document, fetched_at: Time.current } }
        return unless entry
        return registered if registered && registered.updated_at >= entry[:fetched_at]

        materialize(model, registered || model.new(uid: client_id), entry[:document])
      end

      # The authorization response has to carry +iss+ (RFC 9207) for a client known from its document,
      # which Doorkeeper only adds once +issuer+ is set (draft-03, Authorization Response). Only a
      # warning, as the issuer may be resolved per request.
      def self.warn_without_issuer
        return if Doorkeeper.config.issuer.present?

        ::Rails.logger.warn("[DOORKEEPER] use_client_id_metadata_documents needs `issuer` to be set, " \
                            "as the authorization response must carry iss (RFC 9207)")
      end

      def self.cache
        @cache ||= DocumentCache.new
      end

      # Logs why a document is refused, as the client itself only sees invalid_client.
      def self.fetch(client_id)
        document = JSON.parse(HttpFetcher.new.fetch(client_id))
        reason = refusal(client_id, document)
        return log_refusal(client_id, reason) if reason

        warn_without_issuer
        document
      rescue HttpFetcher::FetchError => e
        log_refusal(client_id, "its document could not be fetched: #{e.message}")
      rescue JSON::ParserError
        # Not its message, which older json versions fill with the body as served.
        log_refusal(client_id, "its document is no JSON")
      end

      # Why a document is refused, the first reason that applies, or nil.
      def self.refusal(client_id, document)
        return "its document is no JSON object" unless document.is_a?(Hash)
        return "its document names another client_id" unless document["client_id"] == client_id
        return "its document has malformed redirect_uris, scope or client_name" unless well_typed?(document)
        return "its document declares no authorization code flow" unless code_flow_declared?(document)
        return "its client_name cannot be shown" unless displayable?(display_name(client_id, document["client_name"]))
        return "its document declares no public client" unless public_client?(document)
        return "client_authentication does not offer none" unless public_clients_accepted?

        "its document carries a client secret or both jwks and jwks_uri" unless credentials_allowed?(document)
      end

      # No shared secret, and not both jwks and jwks_uri, which leaves open which keys count
      # (RFC 7591 §2, draft-03, Credential and Key Material Restrictions).
      def self.credentials_allowed?(document)
        document.keys.none? { |key| key.start_with?("client_secret") } &&
          !(document.key?("jwks") && document.key?("jwks_uri"))
      end

      def self.well_typed?(document)
        uris = document["redirect_uris"]
        uris.is_a?(Array) && uris.any? && uris.all? { |uri| uri.is_a?(String) } &&
          document.values_at("scope", "client_name").all? { |value| value.nil? || value.is_a?(String) }
      end

      # A client known from its document gets the authorization code flow only, so its grant and response
      # types, RFC 7591's defaults when absent, have to include it; otherwise what the client declares and
      # what this server supports for it do not intersect (draft-03, Client Information Discovery).
      CODE_FLOW = { "grant_types" => "authorization_code", "response_types" => "code" }.freeze

      def self.code_flow_declared?(document)
        CODE_FLOW.all? do |property, type|
          declared = document[property].nil? ? [type] : document[property]
          declared.is_a?(Array) && declared.all?(String) && declared.include?(type)
        end
      end

      SHARED_SECRET_METHODS = %w[client_secret_basic client_secret_post client_secret_jwt].freeze

      # Public clients only: the method is +none+, or the supported methods (OpenID Connect RP Metadata
      # Choices) include +none+ and no shared-secret one, as ChatGPT's do with +private_key_jwt+. A method
      # named next to them must be among them. Naming neither means +none+, not RFC 7591's default of
      # +client_secret_basic+ (draft-03, Client Authentication).
      def self.public_client?(document)
        method, supported = document.values_at("token_endpoint_auth_method", "token_endpoint_auth_methods_supported")
        return [nil, "none"].include?(method) if supported.nil?
        return false unless supported.is_a?(Array) && supported.all?(String)

        (method.nil? || supported.include?(method)) && supported.include?("none") &&
          (supported & SHARED_SECRET_METHODS).empty?
      end

      # Without +none+ among the client authentication methods, the code could never be exchanged.
      def self.public_clients_accepted?
        Doorkeeper.config.client_authentication_methods.any? { |method| method.name.to_s == "none" }
      end

      # The host leads the name, as the consent screen's only verified hint of who is asking.
      def self.display_name(client_id, client_name)
        host = URI.parse(client_id).host
        client_name.present? ? "#{host}: #{client_name}" : host
      end

      # Fits a varchar(255) column, and puts no control characters, line breaks or bidi controls on the
      # consent screen. Joiners (U+200C, U+200D) stay allowed, as names in many scripts need them.
      UNDISPLAYABLE = /[\p{Cc}\p{Zl}\p{Zp}\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]/

      def self.displayable?(name)
        name.length <= 255 && !name.match?(UNDISPLAYABLE)
      end

      def self.materialize(model, application, document)
        scopes = scopes(document["scope"])
        return log_refusal(application.uid, "leaves no scopes") if scopes.nil?

        redirect_uris = acceptable_redirect_uris(application, document["redirect_uris"])
        return log_refusal(application.uid, "lists no acceptable redirect URI") if redirect_uris.empty?

        application.assign_attributes(
          name: display_name(application.uid, document["client_name"]),
          redirect_uri: redirect_uris.join("\n"),
          scopes: scopes,
          confidential: false,
        )
        assign_keys(application, document) if application.respond_to?(:jwks_uri=)
        application.public_send(:"#{MARKER}=", Time.current) unless materialized?(application)
        # A savepoint, so that losing the uid race leaves a caller's transaction usable for the re-read.
        return application if model.with_primary_role { model.transaction(requires_new: true) { application.save } }

        concurrent_row(model, application) || log_refusal(application.uid, application.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        concurrent_row(model, application)
      end

      def self.assign_keys(application, document)
        application.jwks_uri = jwks_uri(document["jwks_uri"])
        application.confidential = private_key_jwt?(document, application.jwks_uri)
        # Generated on create only, so a public client turning confidential may still lack one.
        application.renew_secret if application.confidential? && application.secret.blank?
      end

      # A client declaring private_key_jwt, with keys to verify it against, on a server offering it, must
      # authenticate with it: as a confidential client, +none+ no longer redeems its codes or refresh tokens.
      # Declared in its supported methods, or, without those, as its method (draft-03, Client Authentication).
      def self.private_key_jwt?(document, jwks_uri)
        declared = document["token_endpoint_auth_methods_supported"] || [document["token_endpoint_auth_method"]]
        jwks_uri.present? && declared.include?("private_key_jwt") &&
          Doorkeeper.config.client_authentication_methods.any? { |method| method.name.to_s == "private_key_jwt" }
      end

      # Kept where the application model has the column, so private_key_jwt can verify the client's
      # assertions: ChatGPT picks it whenever the server offers it. Https only, as the key resolver
      # fetches nothing else (and refuses a malformed one itself), and at most 255 characters, like the uid.
      def self.jwks_uri(uri)
        uri if uri.is_a?(String) && uri.length <= 255 && uri.start_with?("https://")
      end

      # A concurrent first request may have written the row in the meantime, on the primary.
      def self.concurrent_row(model, application)
        return if application.persisted?

        row = model.with_primary_role { model.by_uid(application.uid) }
        row if materialized?(row) && !other_client?(row, application.uid)
      end

      # A document may list redirect URIs this server refuses (e.g. http://localhost); keep the rest.
      # Whitespace would split one URI into several once stored. Out-of-band shows the code to whoever
      # is at the screen, which an unregistered client must not be able to ask for.
      def self.acceptable_redirect_uris(application, uris)
        validator = RedirectUriValidator.new(attributes: [:redirect_uri])
        uris.select do |uri|
          next false if uri.blank? || uri.match?(/\s/) || NonStandard::IETF_WG_OAUTH2_OOB_METHODS.include?(uri)

          probe = application.class.new
          validator.validate_each(probe, :redirect_uri, uri)
          probe.errors.empty?
        end
      end

      # Blank scopes would mean all server scopes, so a client left without any is refused,
      # also under an empty cap.
      def self.scopes(requested)
        allowed = Doorkeeper.config.client_id_metadata_document_scopes
        scopes = if allowed.nil?
                   requested.present? ? OAuth::Scopes.from_string(requested) : Doorkeeper.config.default_scopes
                 elsif requested.present?
                   OAuth::Scopes.from_string(requested) & allowed
                 else
                   OAuth::Scopes.from_array(allowed.to_a)
                 end
        scopes.to_s.presence
      end

      # A fetch error may quote what the document's host sent, so the line is scrubbed like a client_name.
      def self.log_refusal(client_id, reason)
        line = "[DOORKEEPER] client_id #{client_id} refused: #{reason}"
        ::Rails.logger.warn(line.dup.force_encoding(Encoding::UTF_8).scrub("?").gsub(UNDISPLAYABLE, "?"))
        nil
      end
    end
  end
end
