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

          urls_match?(url, client_url)
        rescue URI::InvalidURIError
          false
        end

        # RFC 8252 §7.3 lets only the PORT of a loopback redirect URI vary at
        # runtime. Compare every other component explicitly instead of blanking
        # the port and comparing the reassembled strings: `URI#port=` also
        # clears the userinfo on Ruby >= 4.0, which would let
        # `http://attacker@127.0.0.1/cb` match a registered
        # `http://127.0.0.1/cb`. Comparing components (not `URI#==`) also keeps
        # the exception from widening past the port — e.g. an empty path is not
        # treated as equal to "/".
        def self.urls_match?(url, client_url)
          url.scheme == client_url.scheme &&
            url.userinfo == client_url.userinfo &&
            url.host == client_url.host &&
            url.path == client_url.path &&
            url.query == client_url.query &&
            url.fragment == client_url.fragment
        end

        def self.loopback_uri?(uri)
          IPAddr.new(uri.host).loopback?
        rescue IPAddr::Error, IPAddr::InvalidAddressError
          false
        end

        def self.valid_for_authorization?(url, client_url)
          # client_url is blank when the application was registered without a
          # redirect URI (allow_blank_redirect_uri) — no possible match for
          # redirection based OAuth flows, not an error.
          return false if client_url.blank?

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
