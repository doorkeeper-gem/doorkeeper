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
            application = client.is_a?(Doorkeeper.config.application_model) ? client : client&.application
            Doorkeeper.config.access_token_model.create_for(
              application: application,
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
