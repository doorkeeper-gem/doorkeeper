# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class RefreshTokenRequest < BaseRequest
      include OAuth::Helpers

      validate :token_presence, error: Errors::InvalidRequest
      validate :token,        error: Errors::InvalidGrant
      validate :client,       error: Errors::InvalidClient
      validate :client_match, error: Errors::InvalidGrant
      validate :scope,        error: Errors::InvalidScope
      validate :resource_indicators, error: Errors::InvalidTarget

      attr_reader :access_token, :client, :credentials, :refresh_token
      attr_reader :missing_param

      def initialize(server, refresh_token, credentials, parameters = {}, dpop_proof: nil)
        super(dpop_proof: dpop_proof)
        @server = server
        @refresh_token = refresh_token
        @credentials = credentials
        @grant_type = Doorkeeper::OAuth::REFRESH_TOKEN
        @original_scopes = parameters[:scope] || parameters[:scopes]
        @refresh_token_parameter = parameters[:refresh_token]
        @raw_resource_indicators = parameters[:resource]
        @client = load_client(credentials) if credentials
      end

      private

      # Resolved through +OAuth::Client+ rather than by looking the row up
      # directly, so this grant applies the same rules the other token
      # endpoint grants do: credentials that carry no secret because their
      # authentication method already proved the client's identity
      # (private_key_jwt) resolve by uid alone. The application record is
      # what is returned, since that is what +#client+ has always exposed
      # here.
      def load_client(credentials)
        Doorkeeper::OAuth::Client.authenticate(credentials)&.application
      end

      def before_successful_response
        if refresh_token_revoked_on_use?
          # No locking needed when refresh tokens are revoked on use
          # because the old token is revoked later when the new token is used.
          # This allows multiple concurrent refresh requests to succeed during the
          # transition period, after which the old refresh token will be revoked.
          raise Errors::InvalidGrantReuse if refresh_token.revoked?

          create_access_token
        else
          # Use locking when refresh tokens are revoked immediately
          # to prevent race conditions where multiple tokens could be created
          refresh_token.with_lock do
            raise Errors::InvalidGrantReuse if refresh_token.revoked?

            refresh_token.revoke
            create_access_token
          end
        end
        super
      end

      def refresh_token_revoked_on_use?
        Doorkeeper.config.access_token_model.refresh_token_revoked_on_use?
      end

      def default_scopes
        refresh_token.scopes
      end

      def create_access_token
        attributes = dpop_token_attributes.merge(custom_token_attributes_with_data)

        resource_owner =
          if Doorkeeper.config.polymorphic_resource_owner?
            refresh_token.resource_owner
          else
            refresh_token.resource_owner_id
          end

        if refresh_token_revoked_on_use?
          attributes[:previous_refresh_token] = refresh_token.refresh_token
        end

        # RFC 8707: carry resource indicators to the new access token.
        # If the refresh request specified a (subset of) resource(s), use those;
        # otherwise inherit from the refresh token itself.
        if @resolved_resource_indicators.present?
          unless Doorkeeper.config.access_token_model.resource_indicators_supported?
            raise Errors::MissingResourceColumn, "oauth_access_tokens"
          end

          attributes[:resource] = @resolved_resource_indicators.join(" ")
        elsif refresh_token.try(:resource).present?
          attributes[:resource] = refresh_token.resource
        end

        # RFC6749
        # 1.5.  Refresh Token
        #
        # Refresh tokens are issued to the client by the authorization server and are
        # used to obtain a new access token when the current access token
        # becomes invalid or expires, or to obtain additional access tokens
        # with identical or narrower scope (access tokens may have a shorter
        # lifetime and fewer permissions than authorized by the resource
        # owner).
        #
        # Here we assume that TTL of the token received after refreshing should be
        # the same as that of the original token.
        #
        @access_token = Doorkeeper.config.access_token_model.create_for(
          application: refresh_token.application,
          resource_owner: resource_owner,
          scopes: scopes,
          expires_in: refresh_token.expires_in,
          use_refresh_token: true,
          **attributes,
        )
      end

      def validate_token_presence
        @missing_param = :refresh_token if refresh_token.blank? && @refresh_token_parameter.blank?

        @missing_param.nil?
      end

      def validate_token
        refresh_token.present? && !refresh_token.revoked?
      end

      def validate_client
        return true if credentials.blank?

        client.present?
      end

      # @see https://datatracker.ietf.org/doc/html/rfc6749#section-1.5
      #
      def validate_client_match
        return true if refresh_token.application_id.blank?

        client && refresh_token.application_id == client.id
      end

      def validate_scope
        if @original_scopes.present?
          ScopeChecker.valid?(
            scope_str: @original_scopes,
            server_scopes: refresh_token.scopes,
          )
        else
          true
        end
      end

      # RFC 8707: resource indicators on refresh must be a subset of those
      # bound to the original refresh token (which inherited from the grant).
      #
      # Subset and syntax enforcement run even when no validator is configured
      # as long as the original token is already audience-restricted: a refresh
      # must never widen the audience beyond what the original token carried.
      # Only when the feature is disabled AND the original token has no stored
      # resources is the `resource` parameter ignored entirely.
      def validate_resource_indicators
        original_resources = refresh_token.try(:resource)&.split

        validator = Doorkeeper.config.resource_indicator_validator

        # Feature effectively off: no validator and nothing already bound to
        # enforce against. Ignore the `resource` parameter.
        return true if validator.nil? && original_resources.blank?

        @resolved_resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client,
          grant_resource_indicators: original_resources,
        )
        true
      rescue Errors::InvalidTarget
        false
      end

      def custom_token_attributes_with_data
        refresh_token
          .attributes
          .with_indifferent_access
          .slice(*Doorkeeper.config.custom_access_token_attributes)
          .symbolize_keys
      end

      def dpop_token_attributes
        if client&.confidential && refresh_token.uses_dpop?
          { dpop_jkt: refresh_token.dpop_jkt }.merge(super)
        else
          super
        end
      end

      def validate_dpop_proof
        if refresh_token&.uses_dpop?
          if client&.confidential
            dpop_proof.present? ? dpop_proof.valid? : true
          else
            # Same reason as `BaseRequest#validate_dpop_proof`: a caller that
            # builds this request itself never gets a proof injected, so nil
            # must fail the validation rather than raise.
            !!dpop_proof&.valid? && refresh_token.dpop_binding_matches?(dpop_proof.jkt)
          end
        else
          super
        end
      end
    end
  end
end
