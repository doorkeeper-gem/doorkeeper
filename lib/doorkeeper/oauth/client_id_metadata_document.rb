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

      def self.url_form?(client_id)
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

      # The authorization endpoint's lookup. A registered application wins (draft-02 §7.2);
      # otherwise the document is fetched, and a failed fetch refuses the client even when
      # a row was written from an earlier one (draft-02 §5.1).
      def self.application(client_id)
        model = Doorkeeper.config.application_model
        registered = model.by_uid(client_id)
        return registered if registered && !materialized?(registered)

        entry = cache.fetch(client_id) { (document = fetch(client_id)) && { document: document, fetched_at: Time.current } }
        return unless entry
        return registered if registered && registered.public_send(MARKER) >= entry[:fetched_at]

        materialize(model, registered || model.new(uid: client_id), entry[:document])
      end

      def self.cache
        @cache ||= DocumentCache.new
      end

      def self.fetch(client_id)
        document = JSON.parse(HttpFetcher.new.fetch(client_id))
        document if valid?(client_id, document)
      rescue HttpFetcher::FetchError, JSON::ParserError
        nil
      end

      def self.valid?(client_id, document)
        document.is_a?(Hash) &&
          document["client_id"] == client_id &&
          well_typed?(document) &&
          public_client?(document) &&
          document.keys.none? { |key| key.start_with?("client_secret") }
      end

      def self.well_typed?(document)
        uris = document["redirect_uris"]
        uris.is_a?(Array) && uris.any? && uris.all? { |uri| uri.is_a?(String) } &&
          document.values_at("scope", "client_name").all? { |value| value.nil? || value.is_a?(String) }
      end

      # Only public clients are accepted. An omitted method is refused, as RFC 7591 would default it
      # to +client_secret_basic+.
      def self.public_client?(document)
        document["token_endpoint_auth_method"] == "none"
      end

      # The host leads the name, as the consent screen's only verified hint of who is asking.
      def self.materialize(model, application, document)
        host = URI.parse(application.uid).host
        scopes = scopes(document["scope"])
        return log_refusal(application, "leaves no scopes") if scopes.nil?

        application.assign_attributes(
          name: document["client_name"].present? ? "#{host}: #{document["client_name"]}" : host,
          redirect_uri: acceptable_redirect_uris(application, document["redirect_uris"]).join("\n"),
          scopes: scopes,
          confidential: false,
          MARKER => Time.current,
        )
        return application if model.with_primary_role { application.save }

        concurrent_row(model, application) || log_refusal(application, application.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        concurrent_row(model, application)
      end

      # A concurrent first request may have written the row in the meantime.
      def self.concurrent_row(model, application)
        return if application.persisted?

        row = model.by_uid(application.uid)
        row if row && materialized?(row)
      end

      # A document may list redirect URIs this server refuses (e.g. http://localhost); keep the rest.
      # Whitespace would split one URI into several once stored.
      def self.acceptable_redirect_uris(application, uris)
        validator = RedirectUriValidator.new(attributes: [:redirect_uri])
        uris.select do |uri|
          next false if uri.blank? || uri.match?(/\s/)

          probe = application.class.new
          validator.validate_each(probe, :redirect_uri, uri)
          probe.errors.empty?
        end
      end

      # Blank scopes would mean all server scopes, so a client left without any is refused.
      def self.scopes(requested)
        allowed = Doorkeeper.config.client_id_metadata_document_scopes
        scopes = if allowed.blank?
                   requested.present? ? OAuth::Scopes.from_string(requested) : Doorkeeper.config.default_scopes
                 elsif requested.present?
                   OAuth::Scopes.from_string(requested) & allowed
                 else
                   OAuth::Scopes.from_array(allowed.to_a)
                 end
        scopes.to_s.presence
      end

      def self.log_refusal(application, reason)
        ::Rails.logger.info("[DOORKEEPER] client_id #{application.uid} refused: #{reason}")
        nil
      end
    end
  end
end
