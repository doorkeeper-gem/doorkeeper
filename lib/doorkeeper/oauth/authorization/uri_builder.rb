module Doorkeeper
  module OAuth
    module Authorization
      module URIBuilder
        include Rack::Utils

        extend self

        def uri_with_query(url, parameters = {})
          uri            = URI.parse(url)
          original_query = parse_query(uri.query)
          uri.query      = build_query(original_query.merge(parameters))
          uri.to_s
        end

        def uri_with_fragment(url, parameters = {})
          uri = URI.parse(url)
          uri.fragment = build_query(parameters)
          uri.to_s
        end

        def build_query(parameters = {})
          parameters = parameters.reject { |k, v| v.blank? }
          super parameters
        end
      end
    end
  end
end
