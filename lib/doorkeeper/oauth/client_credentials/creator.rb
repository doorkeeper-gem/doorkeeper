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

        # RFC 8707: a token audience-restricted to one resource must not be
        # handed out for a request targeting another, so the resource takes
        # part in the lookup itself. Filtering the result afterwards would miss
        # a reusable token whenever a newer one exists for a different
        # resource, since the lookup returns only the newest match.
        def find_reusable_token_for(client, scopes, attributes)
          token = find_active_existing_token_for(client, scopes, attributes) do |candidate|
            Doorkeeper.config.access_token_model.resource_indicators_match?(
              candidate, attributes[:resource],
            )
          end

          token if token&.reusable?
        end

        # `revoke_previous_client_credentials_token` keeps a single token per
        # client whatever audience it was issued for, so this lookup stays
        # audience-agnostic.
        def find_revocable_token_for(client, scopes, attributes)
          return unless Doorkeeper.config.revoke_previous_client_credentials_token?

          find_active_existing_token_for(client, scopes, attributes)
        end

        def find_active_existing_token_for(client, scopes, attributes, &filter)
          # An empty hash must stay distinct from nil here: nil ignores custom
          # attributes when matching, while an empty hash only matches tokens
          # that have no custom attributes set.
          custom_attributes = Doorkeeper.config.access_token_model
            .extract_custom_attributes(attributes)
          Doorkeeper.config.access_token_model.matching_token_for(
            client, nil, scopes, custom_attributes: custom_attributes, include_expired: false, &filter
          )
        end
      end
    end
  end
end
