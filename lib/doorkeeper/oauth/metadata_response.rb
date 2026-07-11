# frozen_string_literal: true

module Doorkeeper
  module OAuth
    # OAuth 2.0 Authorization Server Metadata response as described in
    # RFC 8414 (https://www.rfc-editor.org/rfc/rfc8414).
    class MetadataResponse < BaseResponse
      def initialize(base_url, url_builder)
        super()
        @base_url = base_url
        @url_builder = url_builder
      end

      def body
        @body ||= begin
          data = {
            issuer: issuer || @base_url,
            # Only advertise endpoints whose controllers are installed. A
            # controller disabled through skip_controllers has no routes mapping,
            # so endpoint_for resolves it to nil and it is dropped below.
            authorization_endpoint: authorization_endpoint,
            token_endpoint: token_endpoint,
            revocation_endpoint: revocation_endpoint,
            introspection_endpoint: (introspection_endpoint if introspection_enabled?),
            scopes_supported: scopes_supported,
            response_types_supported: response_types_supported,
            response_modes_supported: response_modes_supported,
            grant_types_supported: grant_types_supported,
            token_endpoint_auth_methods_supported: token_endpoint_auth_methods_supported,
            code_challenge_methods_supported: code_challenge_methods_supported,
            # RFC 9207: true only when an issuer is configured, matching the
            # condition under which the iss parameter is emitted. false survives
            # the compaction below, so it is advertised explicitly.
            authorization_response_iss_parameter_supported: config.issuer.present?,
          }
          data.compact!

          # userinfo_endpoint is intentionally advertised as null for backwards
          # compatibility; it is meant to be populated through custom_metadata
          # (e.g. by an OIDC extension), so it must survive the compaction above.
          data[:userinfo_endpoint] = userinfo_endpoint

          data.merge(custom_metadata)
        end
      end

      def status
        :ok
      end

      def headers
        {
          "Cache-Control" => "public",
          "Content-Type" => "application/json; charset=utf-8",
        }
      end

      private

      def config
        @config ||= Doorkeeper.configuration
      end

      def url_for(**args)
        @url_builder.call(**args)
      end

      # Resolve the URL for the given route group, or nil when the group has no
      # routes mapping (i.e. the controller was disabled via skip_controllers).
      def endpoint_for(group, action:)
        mapping = Doorkeeper::Rails::Routes.mapping[group]
        return unless mapping

        url_for(controller: mapping[:controllers], action: action)
      end

      def custom_metadata
        config.custom_metadata.symbolize_keys
      end

      def issuer
        config.issuer
      end

      def authorization_endpoint
        endpoint_for(:authorizations, action: "new")
      end

      def token_endpoint
        endpoint_for(:tokens, action: "create")
      end

      def userinfo_endpoint
        nil
      end

      def revocation_endpoint
        endpoint_for(:tokens, action: "revoke")
      end

      def introspection_endpoint
        endpoint_for(:tokens, action: "introspect")
      end

      def introspection_enabled?
        Doorkeeper.configured? &&
          !config.allow_token_introspection.is_a?(FalseClass)
      end

      def scopes_supported
        config.scopes.to_a
      end

      def response_types_supported
        config.authorization_response_types
      end

      def response_modes_supported
        config.authorization_response_flows.flat_map(&:response_mode_matches).uniq
      end

      def grant_types_supported
        # RFC 8414 lists token-endpoint grant type values (e.g.
        # "authorization_code", "refresh_token"), so derive them from the
        # flows that actually handle a grant_type and use their grant_type
        # value rather than the configured flow name. This drops
        # response-type-only flows such as :implicit and reports the real
        # grant type for flows whose name differs from it (e.g. a URN).
        config.token_grant_types
      end

      # The resolved methods (rather than the raw client_authentication names)
      # reflect what the server actually accepts: unregistered names are
      # dropped by the resolver, and a deprecated client_credentials-only
      # configuration is honored as the source of truth. Legacy callable
      # extractors have no registered method name a client could use, so they
      # are not advertised.
      def token_endpoint_auth_methods_supported
        config.client_authentication_methods.filter_map do |method|
          method.name.to_s if Doorkeeper::ClientAuthentication.get(method.name)
        end
      end

      def code_challenge_methods_supported
        config.pkce_code_challenge_methods_supported
      end
    end
  end
end
