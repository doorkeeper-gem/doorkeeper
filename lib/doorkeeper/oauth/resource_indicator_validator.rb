# frozen_string_literal: true

require "uri"

module Doorkeeper
  module OAuth
    # Validates the `resource` parameter per RFC 8707.
    #
    # The `resource` value MUST be an absolute URI without a fragment component.
    # Multiple `resource` parameters MAY be present.
    #
    # @see https://datatracker.ietf.org/doc/html/rfc8707#section-2
    module ResourceIndicatorValidator
      module_function

      # Whether there is anywhere to record the audience a token was restricted
      # to: the `resource` column the doorkeeper:resource_indicators generator
      # adds to both tables. RFC 8707 also needs a policy deciding which
      # resources are acceptable (resource_indicator_validator), so callers
      # asking whether the extension is usable check both.
      def storage_ready?
        Doorkeeper.config.access_grant_model.resource_indicators_supported? &&
          Doorkeeper.config.access_token_model.resource_indicators_supported?
      end

      # Validates and normalizes an array of resource indicator values.
      #
      # @param resource_indicators [Array<String>, String, nil] One or more resource URIs
      # @param config_validator [Proc, nil] Custom validator from configuration
      # @param client [Doorkeeper::OAuth::Client, nil] The requesting client
      # @param grant_resource_indicators [Array<String>, nil] Resource indicators from the
      #   original authorization grant (for subset enforcement on token requests)
      #
      # @return [Array<String>] Validated resource indicator URIs
      # @raise [Doorkeeper::Errors::InvalidTarget] When validation fails
      def validate!(resource_indicators, config_validator: nil, client: nil, grant_resource_indicators: nil)
        return [] if resource_indicators.blank?

        indicators = Array.wrap(resource_indicators).reject(&:blank?).uniq
        return [] if indicators.empty?

        indicators.each { |uri| validate_uri!(uri) }

        # If the token request specifies resources, they must be a subset of those
        # originally granted (RFC 8707 §2.2).
        raise Errors::InvalidTarget if grant_resource_indicators.present? && (indicators - grant_resource_indicators).any?

        # Custom server policy validation
        raise Errors::InvalidTarget if config_validator && !config_validator.call(indicators, client)

        indicators
      end

      # @return [Boolean] true when the values are syntactically valid
      def valid?(resource_indicators)
        return true if resource_indicators.blank?

        Array(resource_indicators).reject(&:blank?).all? { |uri| valid_uri?(uri) }
      end

      def valid_uri?(uri)
        return false unless uri.is_a?(String)

        parsed = URI.parse(uri)
        # MUST be absolute URI
        return false unless parsed.absolute?
        # MUST NOT include a fragment
        return false if parsed.fragment

        true
      rescue URI::InvalidURIError, TypeError
        false
      end

      def validate_uri!(uri)
        raise Errors::InvalidTarget unless valid_uri?(uri)
      end
    end
  end
end
