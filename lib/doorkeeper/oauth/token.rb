# frozen_string_literal: true

module Doorkeeper
  module OAuth
    class Token
      class << self
        def from_request(request, *methods)
          methods.inject(nil) do |_, method|
            method = self.method(method) if method.is_a?(Symbol)
            credentials = method.call(request)
            break credentials if credentials.present?
          end
        end

        def authenticate(request, *methods)
          if (token = from_request(request, *methods))
            if Doorkeeper.config.stateless_jwt_tokens? && jwt?(token)
              decode_stateless(token)
            else
              access_token = Doorkeeper.config.access_token_model.by_token(token)
              access_token.revoke_previous_refresh_token! if access_token.present? && Doorkeeper.config.refresh_token_enabled?
              access_token
            end
          end
        end

        def from_access_token_param(request)
          request.parameters[:access_token]
        end

        def from_bearer_param(request)
          request.parameters[:bearer_token]
        end

        def from_bearer_authorization(request)
          pattern = /^Bearer /i
          header = request.authorization
          token_from_header(header, pattern) if match?(header, pattern)
        end

        def from_basic_authorization(request)
          pattern = /^Basic /i
          header = request.authorization
          token_from_basic_header(header, pattern) if match?(header, pattern)
        end

        private

        def token_from_basic_header(header, pattern)
          encoded_header = token_from_header(header, pattern)
          decode_basic_credentials_token(encoded_header)
        end

        def decode_basic_credentials_token(encoded_header)
          Base64.decode64(encoded_header).split(/:/, 2).first
        end

        def token_from_header(header, pattern)
          header.gsub(pattern, "")
        end

        def match?(header, pattern)
          header&.match(pattern)
        end

        # Cheap structural check so opaque tokens fall through to the database path
        # without invoking the decoder. A JWT has exactly three dot-separated segments.
        def jwt?(token)
          token.to_s.split(".").length == 3
        end

        # Decodes and verifies a presented JWT without a database read. Returns a
        # StatelessToken on success, or nil on any failure (invalid signature,
        # malformed payload) so the request is treated as unauthenticated.
        def decode_stateless(raw)
          decoder = Doorkeeper.config.jwt_token_decoder
          return nil unless decoder

          claims = decoder.call(raw)
          return nil unless claims.is_a?(Hash)

          application = resolve_stateless_application(claims)
          OAuth::StatelessToken.new(claims: claims, application: application, raw_token: raw)
        rescue StandardError
          nil
        end

        def resolve_stateless_application(claims)
          client_id = claims["client_id"]
          return nil if client_id.blank?

          Doorkeeper.config.application_model.find_by(uid: client_id)
        rescue StandardError
          nil
        end
      end
    end
  end
end
