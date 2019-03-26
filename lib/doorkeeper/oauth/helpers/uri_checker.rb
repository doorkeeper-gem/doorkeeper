# frozen_string_literal: true
require "ipaddr"

module Doorkeeper
  module IPAddrLoopback
    def loopback?
      case @family
      when Socket::AF_INET
        @addr & 0xff000000 == 0x7f000000
      when Socket::AF_INET6
        @addr == 1
      else
        raise AddressFamilyError, "unsupported address family"
      end
    end
  end

  # For backward compatibility with old rubies
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.5.0")
    IPAddr.send(:include, Doorkeeper::IPAddrLoopback)
  end

  module OAuth
    module Helpers
      module URIChecker
        def self.valid?(url)
          return true if native_uri?(url)

          uri = as_uri(url)
          uri.fragment.nil? && !uri.host.nil? && !uri.scheme.nil?
        rescue URI::InvalidURIError
          false
        end

        def self.matches?(url, client_url)
          url = as_uri(url)
          client_url = as_uri(client_url)

          unless client_url.query.nil?
            return false unless query_matches?(url.query, client_url.query)

            # Clear out queries so rest of URI can be tested. This allows query
            # params to be in the request but order not mattering.
            client_url.query = nil
          end

          # RFC8252, Paragraph 7.3
          # @see https://tools.ietf.org/html/rfc8252#section-7.3
          if loopback_uri?(url) && loopback_uri?(client_url)
            url.port = nil
            client_url.port = nil
          end

          url.query = nil
          url == client_url
        end

        def self.loopback_uri?(uri)
          IPAddr.new(uri.host).loopback?
        rescue IPAddr::Error
          false
        end

        def self.valid_for_authorization?(url, client_url)
          valid?(url) && client_url.split.any? { |other_url| matches?(url, other_url) }
        end

        def self.as_uri(url)
          URI.parse(url)
        end

        def self.query_matches?(query, client_query)
          return true if client_query.blank? && query.blank?
          return false if client_query.nil? || query.nil?

          # Will return true independent of query order
          client_query.split("&").sort == query.split("&").sort
        end

        def self.native_uri?(url)
          url == Doorkeeper.configuration.native_redirect_uri
        end
      end
    end
  end
end
