# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # OAuth Client ID Metadata Documents (draft-ietf-oauth-client-id-metadata-document)
    # for public clients: an https client_id is the URL of the client's own metadata,
    # fetched and kept as an application row, since grants and tokens reference one.
    module ClientIdMetadataDocument
      def self.url?(client_id)
        return false unless Doorkeeper.config.use_client_id_metadata_documents?

        uri = URI.parse(client_id.to_s)
        uri.is_a?(URI::HTTPS) && uri.host.present? && uri.path.length > 1 && uri.userinfo.nil? && uri.fragment.nil?
      rescue URI::InvalidURIError
        false
      end

      def self.application(client_id)
        document = cache.fetch(client_id) { fetch(client_id) }
        materialize(client_id, document) if document
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
          document["redirect_uris"].is_a?(Array) && document["redirect_uris"].any? &&
          document["redirect_uris"].all? { |uri| uri.is_a?(String) } &&
          document.fetch("token_endpoint_auth_method", "none") == "none" &&
          document.keys.none? { |key| key.start_with?("client_secret") }
      end

      # The host is part of the name, as the consent screen's only verified hint of who is asking.
      def self.materialize(client_id, document)
        model = Doorkeeper.config.application_model
        application = model.by_uid(client_id) || model.new(uid: client_id)
        host = URI.parse(client_id).host
        application.assign_attributes(
          name: document["client_name"].present? ? "#{document["client_name"]} (#{host})" : host,
          redirect_uri: acceptable_redirect_uris(model, document["redirect_uris"]).join("\n"),
          scopes: scopes(document["scope"]),
          confidential: false,
        )
        application if application.save
      end

      # A document may list redirect URIs this server refuses (e.g. http://localhost); keep the rest.
      def self.acceptable_redirect_uris(model, uris)
        uris.select { |uri| model.new(redirect_uri: uri).tap(&:validate).errors[:redirect_uri].empty? }
      end

      def self.scopes(requested)
        allowed = Doorkeeper.config.client_id_metadata_document_scopes
        return requested.to_s if allowed.blank?

        (requested.present? ? OAuth::Scopes.from_string(requested) & allowed : OAuth::Scopes.from_array(allowed)).to_s
      end
    end
  end
end
