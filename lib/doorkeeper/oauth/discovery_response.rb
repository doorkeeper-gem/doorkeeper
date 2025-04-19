# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class DiscoveryResponse < BaseResponse
      def initialize(root_url, url_builder)
        @root_url = root_url
        @url_builder = url_builder
      end

      def body
        @body ||= {
          issuer: issuer || @root_url,
          authorization_endpoint: authorization_endpoint,
          token_endpoint: token_endpoint,
          revocation_endpoint: revocation_endpoint,
          userinfo_endpoint: userinfo_endpoint,
          scopes_supported: scopes_supported,
          response_types_supported: response_types_supported,
          response_modes_supported: response_modes_supported,
          grant_types_supported: grant_types_supported,
          token_endpoint_auth_methods_supported: token_endpoint_auth_methods_supported,
          code_challenge_methods_supported: code_challenge_methods_supported,
        }.merge(custom_discovery_data)
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

      def custom_discovery_data
        config.custom_discovery_data.symbolize_keys
      end

      def issuer
        config.issuer
      end

      def authorization_endpoint
        mapping = Doorkeeper::Rails::Routes.mapping[:authorizations] || {}

        url_for(
          controller: mapping[:controllers] || "doorkeeper/authorizations",
          action: 'new'
        )
      end

      def token_endpoint
        mapping = Doorkeeper::Rails::Routes.mapping[:tokens] || {}
        
        url_for(
          controller: mapping[:controllers] || "doorkeeper/tokens",
          action: 'create'
        )
      end

      def userinfo_endpoint
        nil
      end

      def revocation_endpoint
        mapping = Doorkeeper::Rails::Routes.mapping[:tokens] || {}
        
        url_for(
          controller: mapping[:controllers] || "doorkeeper/tokens",
          action: 'revoke'
        )
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
        grant_types_supported = config.grant_flows.dup
        grant_types_supported << 'refresh_token' if !!config.refresh_token_enabled?
        grant_types_supported
      end

      # FIXME: https://github.com/doorkeeper-gem/doorkeeper/pull/1770
      def token_endpoint_auth_methods_supported
        %w(none client_secret_basic client_secret_post)
      end

      def code_challenge_methods_supported
        config.pkce_code_challenge_methods_supported
      end
    end
  end
end
