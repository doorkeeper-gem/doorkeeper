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
          url = as_uri(url)
          client_url = as_uri(client_url)
          url.query = nil
          url == client_url
        end

        def self.matches_development_urls?(url)
          return false if Doorkeeper.configuration.development_uris == :disabled

          Doorkeeper.configuration.development_uris.split.any? do |dev_url|
            host_match?(url, dev_url)
          end
        end

        def self.valid_for_authorization?(url, client_url)
          valid?(url) && client_url.split.any? { |other_url| matches?(url, other_url) }
        end

        def self.host_match?(url1, url2)
          host1 = as_uri(url1).host
          host2 = as_uri(url2).host

          # check domains, ignore subdomains
          check_length = [host1.length, host2.length].min
          host1[-check_length..-1] == host2[-check_length..-1]
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
