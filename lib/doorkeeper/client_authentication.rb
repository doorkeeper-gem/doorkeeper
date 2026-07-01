# frozen_string_literal: true

require "doorkeeper/client_authentication/credentials"
require "doorkeeper/client_authentication/fallback_method"
require "doorkeeper/client_authentication/legacy_callable"
require "doorkeeper/client_authentication/method"
require "doorkeeper/client_authentication/registry"

module Doorkeeper
  # Registry of the OAuth client authentication methods (RFC 6749 §2.3)
  # Doorkeeper knows how to process. Each registered method is able to tell
  # whether it +matches_request?+ and how to +authenticate+ it into a
  # Credentials object.
  module ClientAuthentication
    extend Registry

    # Default ordered client authentication methods (RFC 6749 §2.3) used when
    # +client_authentication+ is not configured.
    DEFAULT_METHODS = %i[client_secret_basic client_secret_post none].freeze

    register(
      :none,
      Doorkeeper::OAuth::ClientAuthentication::None,
    )

    register(
      :client_secret_post,
      Doorkeeper::OAuth::ClientAuthentication::ClientSecretPost,
    )

    register(
      :client_secret_basic,
      Doorkeeper::OAuth::ClientAuthentication::ClientSecretBasic,
    )

    # Converts a deprecated +client_credentials+ configuration into the client
    # authentication method names / adapters understood by the registry.
    # Unknown values are warned about and dropped; callables are wrapped in a
    # LegacyCallable adapter. +:none+ (public client support) is appended only
    # for +:from_params+ — the sole legacy method that accepted a bare
    # +client_id+ without a secret — so a Basic-only configuration is not
    # silently broadened.
    def self.from_legacy_client_credentials(methods)
      converted = methods.filter_map { |method| legacy_client_credential(method) }
      converted.push(:none) if methods.include?(:from_params)
      converted
    end

    def self.legacy_client_credential(method)
      case method
      when :from_basic
        :client_secret_basic
      when :from_params
        :client_secret_post
      else
        legacy_extractor_or_nil(method)
      end
    end
    private_class_method :legacy_client_credential

    def self.legacy_extractor_or_nil(method)
      unless method.respond_to?(:call)
        Kernel.warn("[DOORKEEPER] Unknown client_credentials method detected: #{method}")
        return nil
      end

      Kernel.warn(
        "[DOORKEEPER] client_credentials callable extractors are deprecated; wrapping it in a " \
        "legacy client authentication adapter. Register it via " \
        "Doorkeeper::ClientAuthentication.register instead.",
      )
      Method.new(:legacy_callable, LegacyCallable.new(method))
    end
    private_class_method :legacy_extractor_or_nil
  end
end
