require 'fuzzyurl'

module Doorkeeper
  module OAuth
    module Helpers
      module URIChecker
        def self.valid?(url)
          uri = as_uri(url)
          uri.fragment.nil? && !uri.host.nil? && !uri.scheme.nil?
        rescue URI::InvalidURIError
          false
        end

        def self.matches?(url, client_url)
          if Doorkeeper.configuration.wildcard_redirect_uri
            url = as_uri(url)
            fuzzy_client_url = FuzzyURL.new(client_url.to_s)
            return fuzzy_client_url.matches?(url.to_s)
          else
            url, client_url = as_uri(url), as_uri(client_url)
            url.query = nil
            url == client_url
          end
        end

        def self.valid_for_authorization?(url, client_url)
          valid?(url) && client_url.split.any? { |other_url| matches?(url, other_url) }
        end

        def self.as_uri(url)
          URI.parse(url)
        end

        def self.native_uri?(url)
          url == Doorkeeper.configuration.native_redirect_uri
        end
      end
    end
  end
end
