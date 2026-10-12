# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientCredentials
      class Creator
        def call(client, scopes, attributes = {})
          stateless = Doorkeeper.config.stateless_jwt_tokens?
          ensure_stateless_token_support! if stateless

          if Doorkeeper.config.reuse_access_token && !stateless
            reusable_token = find_reusable_token_for(client, scopes, attributes)
            return reusable_token if reusable_token
          end

          existing_token = find_revocable_token_for(client, scopes, attributes)

          with_revocation(existing_token: existing_token) do
            application = client.is_a?(Doorkeeper.config.application_model) ? client : client&.application
            issue_token(application, scopes, attributes)
          end
        end

        private

        # ORM adapters that reimplement token creation (Mongoid, Sequel) do
        # not define build_stateless_token; fail with an actionable error
        # instead of a NoMethodError. The check runs before any reuse or
        # revocation lookup because those adapters do not define the lookup
        # APIs the Creator calls either (extract_custom_attributes,
        # matching_token_for with custom_attributes:), and their NoMethodError
        # must not win over the actionable one.
        def ensure_stateless_token_support!
          model = Doorkeeper.config.access_token_model
          return if model.respond_to?(:build_stateless_token)

          raise Errors::StatelessTokensUnsupported, model
        end

        # A stateless token has no row to reuse, so reuse is skipped the way
        # AccessToken.find_or_create_for skips it. The revocation above still
        # applies to tokens persisted before stateless_jwt_tokens was enabled.
        def issue_token(application, scopes, attributes)
          model = Doorkeeper.config.access_token_model
          token_attributes = { application: application, resource_owner: nil, scopes: scopes, **attributes }

          if Doorkeeper.config.stateless_jwt_tokens?
            model.build_stateless_token(**token_attributes)
          else
            model.create_for(**token_attributes)
          end
        end

        def with_revocation(existing_token:)
          if existing_token && Doorkeeper.config.revoke_previous_client_credentials_token?
            existing_token.with_lock do
              raise Errors::DoorkeeperError, :invalid_token_reuse if existing_token.revoked?

              existing_token.revoke

              yield
            end
          else
            yield
          end
        end

        def find_reusable_token_for(client, scopes, attributes)
          token = find_active_existing_token_for(client, scopes, attributes)

          token if token&.reusable?
        end

        def find_revocable_token_for(client, scopes, attributes)
          return unless Doorkeeper.config.revoke_previous_client_credentials_token?

          find_active_existing_token_for(client, scopes, attributes)
        end

        def find_active_existing_token_for(client, scopes, attributes)
          # An empty hash must stay distinct from nil here: nil ignores custom
          # attributes when matching, while an empty hash only matches tokens
          # that have no custom attributes set.
          custom_attributes = Doorkeeper.config.access_token_model
            .extract_custom_attributes(attributes)
          Doorkeeper.config.access_token_model.matching_token_for(
            client, nil, scopes, custom_attributes: custom_attributes, include_expired: false,
          ) do |token|
            # RFC 8707: a token bound to another audience is a different token.
            # It must neither be reused for this request nor revoked on its
            # behalf, so the resource takes part in the lookup both callers use.
            # It has to be part of the lookup rather than a check on its result,
            # because only the newest match is returned.
            Doorkeeper.config.access_token_model.resource_indicators_match?(
              token, attributes[:resource],
            )
          end
        end
      end
    end
  end
end
