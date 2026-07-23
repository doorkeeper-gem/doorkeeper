# frozen_string_literal: true

require "ipaddr"

module Doorkeeper
  module OAuth
    module Helpers
      module URIChecker
        def self.valid?(url)
          return true if oob_uri?(url)

          uri = as_uri(url)
          valid_scheme?(uri) && iff_host?(uri) && uri.fragment.nil? && uri.opaque.nil?
        rescue URI::InvalidURIError
          false
        end

        # RFC6749, Section 3.1.2.3 requires the requested redirect URI to be
        # compared to the registered redirect URIs using the simple string
        # comparison defined in RFC3986, Section 6.2.1.
        # @see https://datatracker.ietf.org/doc/html/rfc6749#section-3.1.2.3
        def self.matches?(url, client_url)
          return true if url == client_url

          # RFC8252, Paragraph 7.3 allows the port of loopback interface
          # redirect URIs to vary at runtime, so it is ignored when both
          # URIs point to the loopback interface.
          # @see https://datatracker.ietf.org/doc/html/rfc8252#section-7.3
          url = as_uri(url)
          client_url = as_uri(client_url)

          return false unless loopback_uri?(url) && loopback_uri?(client_url)

          url.port = nil
          client_url.port = nil
          # Compare the reassembled strings rather than the URI objects so the
          # URI#== normalizations (e.g. an empty path matching "/") don't
          # widen the exception beyond the port.
          url.to_s == client_url.to_s
        rescue URI::InvalidURIError
          false
        end

        def self.loopback_uri?(uri)
          IPAddr.new(uri.host).loopback?
        rescue IPAddr::Error, IPAddr::InvalidAddressError
          false
        end

        def self.valid_for_authorization?(url, client_url)
          valid?(url) && client_url.split.any? { |other_url| matches?(url, other_url) }
        end

        def self.as_uri(url)
          URI.parse(url)
        end

        def self.valid_scheme?(uri)
          return false if uri.scheme.blank?

          %w[localhost].exclude?(uri.scheme)
        end

        def self.hypertext_scheme?(uri)
          %w[http https].include?(uri.scheme)
        end

        def self.iff_host?(uri)
          !(hypertext_scheme?(uri) && uri.host.blank?)
        end

        def self.oob_uri?(uri)
          NonStandard::IETF_WG_OAUTH2_OOB_METHODS.include?(uri)
        end
      end
    end
  end
end
