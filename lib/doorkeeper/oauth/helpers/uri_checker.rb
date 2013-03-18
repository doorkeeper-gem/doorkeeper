module Doorkeeper
  module OAuth
    module Helpers
      module URIChecker
        def self.valid?(url)
          return false if url.nil?
          uri = as_uri(url)
          uri.fragment.nil? && !uri.host.nil? && !uri.scheme.nil?
        rescue URI::InvalidURIError
          false
        end

        def self.matches?(url, client_url)
          url, client_url = as_uri(url), as_uri(client_url)
          url.query = nil
          url == client_url
        end

        def self.valid_for_authorization?(url, client_url)
          valid?(url) && valid?(client_url) && matches?(url, client_url)
        end

        def self.as_uri(url)
          URI.parse(url)
        end

        def self.test_uri?(url)
          url == Doorkeeper.configuration.test_redirect_uri
        end
      end
    end
  end
end
