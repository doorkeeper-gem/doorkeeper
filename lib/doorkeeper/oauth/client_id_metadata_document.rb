# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # OAuth Client ID Metadata Documents (draft-ietf-oauth-client-id-metadata-document)
    # for public clients: an https client_id is the URL of the client's own metadata,
    # fetched and kept as an application row, since grants and tokens reference one.
    #
    # Rows written from a document carry a timestamp in MARKER, which is what tells them
    # apart from registered applications (draft-02 §7.1). ActiveRecord only.
    module ClientIdMetadataDocument
      MARKER = :client_id_metadata_materialized_at

      def self.url?(client_id)
        Doorkeeper.config.use_client_id_metadata_documents? && url_form?(client_id)
      end

      # At most 255 characters, as the uid column holds no more on MySQL.
      def self.url_form?(client_id)
        return false if client_id.to_s.length > 255

        uri = URI.parse(client_id.to_s)
        uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.length > 1 && uri.userinfo.nil? &&
          uri.fragment.nil? && (uri.path.split("/").map { |segment| URI.decode_uri_component(segment) } & %w[. ..]).empty?
      rescue URI::InvalidURIError, ArgumentError
        false
      end

      def self.materialized?(application)
        application.respond_to?(MARKER) && application.public_send(MARKER).present?
      end

      # A row written from a document while the option was on, and is no longer.
      def self.orphaned?(application)
        materialized?(application) && !Doorkeeper.config.use_client_id_metadata_documents?
      end

      # A row written from a document stands for one client_id only, compared as a simple string
      # (draft-02 §3). The database may compare more loosely: MySQL's default collations ignore case
      # and accents, some of them trailing spaces as well.
      def self.other_client?(application, client_id)
        materialized?(application) && application.uid != client_id.to_s
      end

      # The authorization endpoint's lookup. A registered application wins (draft-02 §7.2);
      # otherwise the document is fetched, and a failed fetch refuses the client even when
      # a row was written from an earlier one (draft-02 §5.1).
      def self.application(client_id)
        model = Doorkeeper.config.application_model
        registered = model.by_uid(client_id)
        return registered if registered && !materialized?(registered)
        return if other_client?(registered, client_id)

        entry = cache.fetch(client_id) { (document = fetch(client_id)) && { document: document, fetched_at: Time.current } }
        return unless entry
        return registered if registered && registered.public_send(MARKER) >= entry[:fetched_at]

        materialize(model, registered || model.new(uid: client_id), entry[:document])
      end

      def self.cache
        @cache ||= DocumentCache.new
      end

      def self.fetch(client_id)
        body = HttpFetcher.new.fetch(client_id).dup.force_encoding(Encoding::UTF_8)
        return unless body.valid_encoding?

        document = JSON.parse(body)
        document if valid?(client_id, document)
      rescue HttpFetcher::FetchError, JSON::ParserError
        nil
      end

      def self.valid?(client_id, document)
        document.is_a?(Hash) &&
          document["client_id"] == client_id &&
          well_typed?(document) &&
          displayable?(display_name(client_id, document["client_name"])) &&
          public_client?(document) &&
          public_clients_accepted? &&
          document.keys.none? { |key| key.start_with?("client_secret") }
      end

      def self.well_typed?(document)
        uris = document["redirect_uris"]
        uris.is_a?(Array) && uris.any? && uris.all? { |uri| uri.is_a?(String) } &&
          document.values_at("scope", "client_name").all? { |value| value.nil? || value.is_a?(String) }
      end

      SHARED_SECRET_METHODS = %w[client_secret_basic client_secret_post client_secret_jwt].freeze

      # +none+ as the method or among the supported ones (OpenID Connect RP Metadata Choices) makes
      # a public client, unless a shared-secret method is named. ChatGPT prefers +private_key_jwt+.
      # An omitted method is refused, as RFC 7591 defaults it to +client_secret_basic+.
      def self.public_client?(document)
        methods = [document["token_endpoint_auth_method"], *Array(document["token_endpoint_auth_methods_supported"])]
        methods.include?("none") && (methods & SHARED_SECRET_METHODS).empty?
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
        return log_refusal(application, "leaves no scopes") if scopes.nil?

        redirect_uris = acceptable_redirect_uris(application, document["redirect_uris"])
        return log_refusal(application, "lists no acceptable redirect URI") if redirect_uris.empty?

        application.assign_attributes(
          name: display_name(application.uid, document["client_name"]),
          redirect_uri: redirect_uris.join("\n"),
          scopes: scopes,
          confidential: false,
          MARKER => Time.current,
        )
        # A savepoint, so that losing the uid race leaves a caller's transaction usable for the re-read.
        return application if model.with_primary_role { model.transaction(requires_new: true) { application.save } }

        concurrent_row(model, application) || log_refusal(application, application.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        concurrent_row(model, application)
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

      def self.log_refusal(application, reason)
        ::Rails.logger.warn("[DOORKEEPER] client_id #{application.uid} refused: #{reason}")
        nil
      end
    end
  end
end
