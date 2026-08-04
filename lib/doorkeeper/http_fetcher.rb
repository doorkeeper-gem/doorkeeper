# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "resolv"
require "uri"

module Doorkeeper
  # Fetches a small operator-untrusted JSON document — a client's jwks_uri
  # today — over HTTPS: redirects are never followed and any status other
  # than 200 OK is an error.
  #
  # SSRF hardening: the host is resolved up front and the request is refused
  # when any resolved address falls into an RFC 6890 special-use range
  # (loopback, private-use, link-local, ...). The connection is then pinned
  # to the vetted address via Net::HTTP#ipaddr= so a second, post-check DNS
  # resolution (DNS rebinding) cannot redirect the request; TLS is still
  # negotiated and verified against the original hostname. An exception for
  # authorization servers themselves running on a loopback interface is
  # intentionally not implemented. These rules follow the fetch hardening of
  # draft-ietf-oauth-client-id-metadata-document (Sections 6.5 / 6.6), which
  # fetches documents from the same kind of client-chosen URL.
  #
  # The response body is bounded and so is the total time spent reading it:
  # a per-read timeout alone does not stop a server that dribbles bytes out
  # indefinitely.
  #
  # Everything about the response is chosen by whoever hosts the document —
  # which is whoever supplied the URL — so no failure mode here may escape
  # as anything other than a FetchError.
  class HttpFetcher
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    # draft-ietf-oauth-client-id-metadata-document Section 6.6 recommends a
    # maximum response size of 5 kilobytes for a document like this.
    MAX_RESPONSE_SIZE = 5 * 1024

    # Ceiling on the whole exchange, so a body delivered one byte per
    # READ_TIMEOUT cannot hold the connection (and the thread) for hours.
    MAX_TOTAL_TIME = 10

    # The document is served as JSON, either "application/json" or an
    # "application/<more specific>+json" variant. A response declaring
    # anything else plainly serves something other than the document sought
    # and is refused without being parsed. A response declaring no media type
    # at all is tolerated — the check is there to catch such a URL early, not
    # as a security control, since the body still has to parse and validate
    # in the caller.
    JSON_MEDIA_TYPE = %r{\Aapplication/([\w.+-]+\+)?json\z}i

    # RFC 6890 special-purpose IPv4/IPv6 registries, plus multicast ranges
    # (224.0.0.0/4, ff00::/8), which are equally unfit as a document origin.
    SPECIAL_USE_RANGES = [
      "0.0.0.0/8",          # "this host on this network"
      "10.0.0.0/8",         # private-use
      "100.64.0.0/10",      # shared address space (CGN)
      "127.0.0.0/8",        # loopback
      "169.254.0.0/16",     # link-local
      "172.16.0.0/12",      # private-use
      "192.0.0.0/24",       # IETF protocol assignments
      "192.0.2.0/24",       # documentation (TEST-NET-1)
      "192.88.99.0/24",     # 6to4 relay anycast
      "192.168.0.0/16",     # private-use
      "198.18.0.0/15",      # benchmarking
      "198.51.100.0/24",    # documentation (TEST-NET-2)
      "203.0.113.0/24",     # documentation (TEST-NET-3)
      "224.0.0.0/4",        # multicast
      "240.0.0.0/4",        # reserved (includes limited broadcast)
      "::/128",             # unspecified
      "::1/128",            # loopback
      # IPv4-compatible addresses (::a.b.c.d), deprecated by RFC 4291
      # Section 2.5.5.1. Unlike the IPv4-mapped form handled in
      # .special_use? these carry no ::ffff: marker, so they are refused
      # wholesale rather than delegated to the embedded IPv4 address. The
      # range also covers the two entries above.
      "::/96",
      "64:ff9b::/96",       # IPv4-IPv6 translation
      "100::/64",           # discard-only
      "2001::/23",          # IETF protocol assignments (TEREDO, ORCHID, ...)
      "2001:db8::/32",      # documentation
      "2002::/16",          # 6to4
      "fc00::/7",           # unique-local
      "fe80::/10",          # link-local
      "ff00::/8",           # multicast
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    FetchError = Class.new(StandardError)

    # Everything a host can fail at while answering, so that it surfaces as
    # a rejected client rather than an exception out of the endpoint.
    #
    # Net::HTTPBadResponse and Net::HTTPHeaderSyntaxError are listed
    # explicitly because they descend straight from StandardError, *not*
    # from Net::ProtocolError: a host answering with a mangled status line
    # or header field raises them out of Net::HTTP.
    TRANSPORT_ERRORS = [
      Timeout::Error,
      SystemCallError,
      SocketError,
      IOError,
      OpenSSL::SSL::SSLError,
      Net::ProtocolError,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Resolv::ResolvError,
      # Only reachable if a body is decompressed despite the identity
      # Accept-Encoding requested below. Ruby can be built without zlib.
      (Zlib::Error if defined?(::Zlib::Error)),
    ].compact.freeze

    def initialize(resolver: Resolv)
      @resolver = resolver
    end

    # @param url [String] an already validated https:// URL
    # @return [String] the response body
    # @raise [FetchError] on resolution, transport or non-200 failures
    def fetch(url)
      uri = URI.parse(url)
      # URI.parse("https:foo") yields a URI::HTTPS whose host is nil, so a
      # caller's is_a?(URI::HTTPS) validation does not guarantee a host —
      # and Resolv raises ArgumentError, not ResolvError, when handed nil.
      raise FetchError, "#{url.inspect} has no host" if uri.host.blank?

      address = vetted_address_for(uri.host)

      perform_request(uri, address)
    rescue *TRANSPORT_ERRORS => e
      raise FetchError, "#{e.class}: #{e.message}"
    end

    def self.special_use?(address)
      ip = address.is_a?(IPAddr) ? address : IPAddr.new(address.to_s)
      # An IPv4-mapped IPv6 address is exactly as special-use as its
      # embedded IPv4 address: ::ffff:127.0.0.1 must be refused while a
      # mapped form of a public address stays reachable.
      return special_use?(ip.native) if ip.ipv4_mapped?

      SPECIAL_USE_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    private

    def vetted_address_for(host)
      addresses = @resolver.getaddresses(host)
      raise FetchError, "could not resolve #{host}" if addresses.empty?

      # Every resolved address must be acceptable: pinning to one vetted
      # address below keeps the connection off the others, but a host that
      # mixes public and special-use records is treated as hostile.
      if addresses.any? { |address| self.class.special_use?(address) }
        raise FetchError, "#{host} resolves to a special-use address (RFC 6890)"
      end

      addresses.first.to_s
    end

    def perform_request(uri, address)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.ipaddr = address
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(
        uri.request_uri,
        # Without an explicit Accept-Encoding, Net::HTTP negotiates gzip and
        # inflates the body itself, which would both feed attacker-chosen
        # bytes to zlib and turn the Content-Length check below into a check
        # on the compressed size. A 5 kilobyte document does not need it.
        { "Accept" => "application/json", "Accept-Encoding" => "identity" },
      )
      deadline = monotonic_now + MAX_TOTAL_TIME
      body = nil

      http.start do |connection|
        # Net::HTTP never follows redirects on its own; a 3xx just fails
        # the status check below.
        connection.request(request) do |response|
          raise FetchError, "expected 200 OK from #{uri.host}, got #{response.code}" unless response.is_a?(Net::HTTPOK)

          verify_media_type!(response, uri.host)
          body = bounded_body(response, uri.host, deadline)
        end
      end

      body
    end

    def verify_media_type!(response, host)
      declared = response["Content-Type"]
      return if declared.blank?

      media_type = declared.split(";").first.to_s.strip
      return if JSON_MEDIA_TYPE.match?(media_type)

      raise FetchError, "#{host} served #{media_type.inspect}, which is not a JSON media type"
    end

    # Reads the response in chunks so an oversized (or endlessly dribbled)
    # body is abandoned instead of buffered in full. Raising here unwinds
    # out of Net::HTTP#start, which closes the connection.
    def bounded_body(response, host, deadline)
      declared = response["Content-Length"]
      if declared && declared.to_i > MAX_RESPONSE_SIZE
        raise FetchError, "#{host} declares a #{declared} byte document, over the " \
                          "#{MAX_RESPONSE_SIZE} byte limit"
      end

      body = +""

      response.read_body do |chunk|
        body << chunk

        if body.bytesize > MAX_RESPONSE_SIZE
          raise FetchError, "the document from #{host} exceeds #{MAX_RESPONSE_SIZE} bytes"
        elsif monotonic_now > deadline
          raise FetchError, "reading the document from #{host} took too long"
        end
      end

      body
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
