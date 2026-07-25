# frozen_string_literal: true

require "uri"

module Doorkeeper
  module ClientIdMetadata
    # Validates a client_id URL against the constraints of the Client ID
    # Metadata Document draft, Section 3: https scheme, a path component,
    # no dot path segments, no fragment and no userinfo. A query string is
    # only SHOULD NOT per the draft, so it is tolerated here.
    module UrlValidator
      DOT_SEGMENTS = %w[. ..].freeze

      # The client_id URL is stored in the application table's uid column,
      # which the generated migration declares as +t.string+ — 255 characters
      # on MySQL, where an over-long value is a database error rather than a
      # rejected client. A URL that could never be materialized is refused
      # here instead, before anything is fetched.
      MAX_LENGTH = 255

      def self.valid?(url)
        url = url.to_s
        return false if url.length > MAX_LENGTH

        uri = URI.parse(url)

        uri.is_a?(URI::HTTPS) &&
          uri.host.present? &&
          uri.path.present? &&
          uri.fragment.nil? &&
          uri.userinfo.nil? &&
          no_dot_segments?(uri.path)
      rescue URI::InvalidURIError
        false
      end

      # Segments are compared after percent-decoding, so "%2e%2e" counts as
      # the ".." it normalizes to rather than slipping through as an ordinary
      # segment.
      def self.no_dot_segments?(path)
        path.split("/").none? do |segment|
          DOT_SEGMENTS.include?(segment) || DOT_SEGMENTS.include?(percent_decode(segment))
        end
      end
      private_class_method :no_dot_segments?

      def self.percent_decode(segment)
        return segment unless segment.include?("%")

        segment.gsub(/%[0-9A-Fa-f]{2}/) { |escape| escape[1, 2].hex.chr }
      end
      private_class_method :percent_decode
    end
  end
end
