# frozen_string_literal: true

module Doorkeeper
  module OAuth
    module ClientCredentials
      class Creator
        def call(client, scopes, attributes = {})
          if Doorkeeper.config.reuse_access_token
            reusable_token = find_reusable_token_for(client, scopes, attributes)
            return reusable_token if reusable_token
          end

          existing_token = find_revocable_token_for(client, scopes, attributes)

          with_revocation(existing_token: existing_token) do
            Doorkeeper.config.access_token_model.create_for(
              application: application_for(client),
              resource_owner: nil,
              scopes: scopes,
              **attributes,
            )
          end
        end

        private

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

        # A token that would outlive +public_client_access_token_expires_in+
        # is not reused, so the cap holds for a public client whatever tokens
        # it was issued before; a new, capped token is issued instead.
        #
        # The cap is checked on the token found rather than inside the lookup
        # +find_revocable_token_for+ shares: there, an over-cap token must
        # still be found, so that +revoke_previous_client_credentials_token+
        # revokes it when the capped token replaces it.
        def find_reusable_token_for(client, scopes, attributes)
          token = find_active_existing_token_for(client, scopes, attributes)
          return unless token&.reusable?

          token if Authorization::Token.within_public_client_expires_in?(
            Doorkeeper.config, application_for(client), token,
          )
        end

        def application_for(client)
          client.is_a?(Doorkeeper.config.application_model) ? client : client&.application
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
