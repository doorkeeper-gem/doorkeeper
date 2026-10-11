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

      def initialize(server, refresh_token, credentials, parameters = {})
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

      # RFC 6749 §6: a `scope` parameter that is omitted "is treated as equal
      # to the scope originally granted by the resource owner", and a
      # requested scope must not exceed it. Both are the scope the presented
      # refresh token carries, not the scope of the access token issued with
      # it, which the client may have narrowed on an earlier refresh.
      def default_scopes
        granted_scopes
      end

      # Scope of the presented refresh token. Without the
      # `refresh_token_scopes` column the model reports the access token
      # scope here, which is the behavior Doorkeeper had before the column
      # existed. An access token model that does not implement
      # `refresh_token_scopes` at all (the Sequel and MongoDB adapters ship
      # their own mixins) gets that same behavior.
      def granted_scopes
        @granted_scopes ||= refresh_token.try(:refresh_token_scopes) || refresh_token.scopes
      end

      # True when the access token model implements the granted-scope API
      # and has the column to store it.
      def refresh_token_scopes_supported?
        Doorkeeper.config.access_token_model.try(:refresh_token_scopes_supported?)
      end

      def create_access_token
        attributes = {}.merge(custom_token_attributes_with_data)

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

        attributes.merge!(refresh_chain_attributes)

        @access_token = Doorkeeper.config.access_token_model.create_for(
          application: refresh_token.application,
          resource_owner: resource_owner,
          scopes: scopes,
          expires_in: access_token_expires_in,
          use_refresh_token: true,
          **attributes,
        )
      end

      # What the new record inherits from the presented refresh token as the
      # next link of the same refresh chain.
      def refresh_chain_attributes
        attributes = {}

        # RFC 6749 §6: "If a new refresh token is issued, the refresh token
        # scope MUST be identical to that of the refresh token included by
        # the client in the request." Carried explicitly so that a narrowed
        # access token does not narrow the refresh token issued with it.
        attributes[:refresh_token_scopes] = granted_scopes.to_s if refresh_token_scopes_supported?

        # The new record continues the refresh token family of the presented
        # refresh token, so that revoking any refresh token of the chain
        # reaches every token issued from the same grant (RFC 7009 §2.1).
        # Access token models that do not track families (no column, or the
        # Sequel and MongoDB adapters, which ship their own mixins) have none
        # to continue.
        family_id = refresh_token.try(:ensure_refresh_token_family_id!)
        attributes[:refresh_token_family_id] = family_id if family_id.present?

        attributes
      end

      def resource_owner
        if Doorkeeper.config.polymorphic_resource_owner?
          refresh_token.resource_owner
        else
          refresh_token.resource_owner_id
        end
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
      # The TTL of the refreshed token is therefore that of the original token,
      # so that a lifetime given to the grant the token was first issued with
      # survives refreshing (#1364). +custom_access_token_expires_in+ is still
      # consulted, with +Doorkeeper::OAuth::REFRESH_TOKEN+ as the grant type,
      # so a host can decide the TTL of refreshed tokens explicitly; the TTL
      # of the original token is only inherited when the callable returns nil
      # for this grant (or none is configured).
      #
      # The context carries the resource owner record only with a polymorphic
      # resource owner; otherwise the refresh token stores its id alone, and
      # +resource_owner+ is nil as in the client_credentials grant.
      #
      # The context is built directly rather than through
      # +Authorization::Token.build_context+, which unwraps its argument
      # through #application or #client: that suits the OAuth client the other
      # grants pass, but would replace this application record with whatever
      # an application model responding to either method returns (a
      # +belongs_to :client+ association, say).
      def access_token_expires_in
        context = Authorization::Context.new(
          client: refresh_token.application,
          grant_type: grant_type,
          scopes: scopes,
          resource_owner: Doorkeeper.config.polymorphic_resource_owner? ? resource_owner : nil,
        )

        Authorization::Token.access_token_expires_in(server, context) { refresh_token.expires_in }
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
            server_scopes: granted_scopes,
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

        # The validator receives the OAuth client, as it does at the
        # authorization endpoint and for every other grant, rather than the
        # application record #client holds here.
        @resolved_resource_indicators = ResourceIndicatorValidator.validate!(
          @raw_resource_indicators,
          config_validator: validator,
          client: client && Doorkeeper::OAuth::Client.new(client),
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
    end
  end
end
