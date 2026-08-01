# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "resolv"
require "timeout"
require "uri"

module Doorkeeper
  # Fetches a small operator-untrusted JSON document — a client's jwks_uri
  # today — over HTTPS: redirects are never followed and any status other
  # than 200 OK is an error.
  #
  # SSRF hardening: the host is resolved up front and the request is refused
  # when any resolved address falls into an RFC 6890 special-use range
  # (loopback, private-use, link-local, ...). The connection is then pinned
  # to a vetted address via Net::HTTP#ipaddr= so a second, post-check DNS
  # resolution (DNS rebinding) cannot redirect the request; TLS is still
  # negotiated and verified against the original hostname. When that address
  # cannot be connected to, the host's remaining vetted addresses are tried
  # in turn. An exception for authorization servers themselves running on a
  # loopback interface is intentionally not implemented. These rules follow
  # the fetch hardening of draft-ietf-oauth-client-id-metadata-document
  # (Sections 8.6 / 8.7), which fetches documents from the same kind of
  # client-chosen URL.
  #
  # The response is bounded in size — headers and body alike — and so is
  # the time the whole exchange may take: a per-read timeout alone does not
  # stop a server that dribbles bytes out indefinitely.
  #
  # Everything about the response is chosen by whoever hosts the document —
  # which is whoever supplied the URL — so no failure mode here may escape
  # as anything other than a FetchError.
  class HttpFetcher
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 5

    # draft-ietf-oauth-client-id-metadata-document Section 8.7 recommends a
    # maximum response size of 5 kilobytes for a document like this.
    MAX_RESPONSE_SIZE = 5 * 1024

    # Net::HTTP reads the status line, every header line and every chunk-size
    # line of a chunked body through its buffered socket with no limit on
    # their length — and before the response object exists, so before
    # anything below could look at it. What a host could push in that phase
    # would be bounded by nothing but its bandwidth and MAX_TOTAL_TIME. The
    # budget is therefore enforced at the socket: every byte read for the
    # exchange counts, and the exchange is abandoned once it has read more
    # than a document and the headers around it could legitimately need.
    MAX_HEADER_SIZE = 8 * 1024
    MAX_EXCHANGE_SIZE = MAX_RESPONSE_SIZE + MAX_HEADER_SIZE

    # Ceiling on the HTTP exchange — connect, headers and body — so a host
    # answering a byte at a time cannot hold the connection (and the thread
    # reading it) for hours. Net::HTTP has no such setting of its own: its
    # timeouts are per phase, and read_timeout starts over on every
    # successful read, so neither a dribbled header block nor a dribbled body
    # ever trips one. The ceiling is therefore held twice over: the per-phase
    # timeouts are trimmed to what is left of it as the exchange goes on, and
    # a wall clock around the whole exchange catches the phases those
    # timeouts cannot see. The ceiling starts once the host's addresses have
    # been vetted: resolution has to happen first, and is bounded by whatever
    # timeouts the deployment's resolver applies rather than by this
    # constant.
    MAX_TOTAL_TIME = 10

    # The document is served as JSON, either "application/json" or an
    # "application/<more specific>+json" variant. A response declaring
    # anything else plainly serves something other than the document sought
    # and is refused without being parsed. A response declaring no media type
    # at all is tolerated — the check is there to catch such a URL early, not
    # as a security control, since the body still has to parse and validate
    # in the caller.
    JSON_MEDIA_TYPE = %r{\Aapplication/([\w.+-]+\+)?json\z}i

    # U+FEFF, which RFC 8259 Section 8.1 lets a reader ignore at the start of
    # a JSON text.
    BYTE_ORDER_MARK = "\uFEFF"

    # Every non-globally-reachable range in the IANA special-purpose address
    # registries RFC 6890 established (including the ranges registered
    # after it: RFC 8215, RFC 9602, RFC 9637, RFC 9780), plus multicast
    # (224.0.0.0/4, ff00::/8), which is equally unfit as a document origin.
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
      "64:ff9b:1::/48",     # local-use IPv4-IPv6 translation (RFC 8215)
      "100::/64",           # discard-only
      "100:0:0:1::/64",     # dummy prefix (RFC 9780)
      "2001::/23",          # IETF protocol assignments (TEREDO, ORCHID, ...)
      "2001:db8::/32",      # documentation
      "2002::/16",          # 6to4
      "3fff::/20",          # documentation (RFC 9637)
      "5f00::/16",          # SRv6 segment identifiers (RFC 9602)
      "fc00::/7",           # unique-local
      "fe80::/10",          # link-local
      "ff00::/8",           # multicast
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    # The range a TCP port can occupy; anything else was never connectable.
    PORT_RANGE = (1..65_535)

    FetchError = Class.new(StandardError)

    # A transport failure raised while the connection was still being
    # established. We'll try to connect to another address if we see this
    # error.
    #
    # Note that this includes some errors that can happen after establishing a
    # TCP connection such as failing to complete a TLS handshake.
    ConnectError = Class.new(StandardError)
    private_constant :ConnectError

    # The buffered socket Net::HTTP reads through, counting what it reads.
    # Only the fill is overridden: net-protocol has kept the buffer's shape
    # across its versions (a fill appends to the unread bytes, a consume
    # advances past them), so the count is taken as the growth of the unread
    # buffer around each fill.
    class BoundedBufferedIO < Net::BufferedIO
      attr_accessor :byte_budget, :host

      private

      def rbuf_fill
        before = unread_bytes
        super
        @bytes_read = (@bytes_read || 0) + [unread_bytes - before, 0].max
        return if byte_budget.nil? || @bytes_read <= byte_budget

        raise FetchError, "the response from #{host} exceeds #{byte_budget} bytes, headers included"
      end

      def unread_bytes
        @rbuf.bytesize - (@rbuf_offset || 0)
      end
    end
    private_constant :BoundedBufferedIO

    # Swaps the socket for the counting one as soon as the connection (TLS
    # handshake included) is up: on_connect is the hook Net::HTTP calls right
    # after wrapping the socket and before reading anything from it. Mixed
    # into the one Net::HTTP instance rather than subclassing Net::HTTP, so
    # that whatever Net::HTTP resolves to when a fetch is made — a test
    # double's subclass included — is what gets extended.
    module BoundedExchange
      attr_accessor :byte_budget

      private

      def on_connect
        @socket = BoundedBufferedIO.new(
          @socket.io,
          read_timeout: @socket.read_timeout,
          write_timeout: @socket.write_timeout,
          continue_timeout: @socket.continue_timeout,
          debug_output: @socket.debug_output,
        )
        @socket.byte_budget = byte_budget
        @socket.host = address
        super
      end
    end
    private_constant :BoundedExchange

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
      # #hostname, not #host: the two differ for an IPv6 literal, where
      # #host keeps the brackets the URL wrote it in ("[::1]") and nothing
      # downstream — neither the resolver nor the special-use check — reads
      # that as an address. UrlValidator accepts such a URL, so the fetcher
      # has to agree with it about what is fetchable.
      raise FetchError, "#{url.inspect} has no host" if uri.hostname.blank?
      # URI.parse accepts any integer as a port, but Net::HTTP builds the
      # connection address out of it, where a value too large to be a port
      # raises TypeError — not one of the TRANSPORT_ERRORS below. Refusing it
      # here keeps every caller's URL, however it was validated, from turning
      # into an exception out of the endpoint.
      raise FetchError, "#{url.inspect} has an out-of-range port" unless PORT_RANGE.cover?(uri.port)

      addresses = vetted_addresses_for(uri.hostname)
      # One deadline covers connection attempts to all addresses in aggregate.
      deadline = monotonic_now + MAX_TOTAL_TIME
      # If we attempt to connect to multiple addresses and all of them fail,
      # arbitrarily surface the last error we received although all of them are
      # equally valid.
      last_error = nil

      # The deadline trims Net::HTTP's per-phase timeouts, but those only
      # cover the phases Net::HTTP times at all: a status line or header
      # block dribbled a byte at a time keeps resetting read_timeout and
      # never trips it. So the same ceiling is also held as a wall clock
      # around everything from the first connection attempt to the last body
      # byte. The Timeout::Error it raises is one of the TRANSPORT_ERRORS
      # below — or, while no connection is up yet, a ConnectError that ends
      # the loop, the deadline having passed by then.
      Timeout.timeout(MAX_TOTAL_TIME, Timeout::Error, "the exchange with #{uri.hostname} took too long") do
        addresses.each do |address|
          break if last_error && monotonic_now >= deadline

          return perform_request(uri, address, deadline)
        rescue ConnectError => e
          last_error = e
        end
      end

      raise FetchError, "could not connect to #{uri.hostname}: #{last_error.message}"
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

    def vetted_addresses_for(host)
      addresses = @resolver.getaddresses(host)
      raise FetchError, "could not resolve #{host}" if addresses.empty?

      # Every resolved address must be acceptable: pinning to one vetted
      # address below keeps the connection off the others, but a host that
      # mixes public and special-use records is treated as hostile.
      if addresses.any? { |address| self.class.special_use?(address) }
        raise FetchError, "#{host} resolves to a special-use address (RFC 6890)"
      end

      addresses.map(&:to_s)
    end

    def connection_for(uri, address, deadline)
      remaining = remaining_until(deadline)
      raise ConnectError, "no time left to connect to #{address}" if remaining <= 0

      Net::HTTP.new(uri.hostname, uri.port).tap do |http|
        http.extend(BoundedExchange)
        http.byte_budget = MAX_EXCHANGE_SIZE
        http.use_ssl = true
        http.ipaddr = address
        # Net::HTTP can use up to the whole `open_timeout` establishing the TCP
        # connection and again for the TLS handshake. Rather than potentially
        # exceeding `MAX_TOTAL_TIME` by up to `OPEN_TIMEOUT` seconds, we pass
        # in half the timeout to keep the true open time within `OPEN_TIMEOUT`.
        #
        # The initial request is unaffected because half of `MAX_TOTAL_TIME` is
        # not less than `OPEN_TIMEOUT`.
        http.open_timeout = [OPEN_TIMEOUT, remaining / 2.0].min
        http.read_timeout = READ_TIMEOUT
        # Disable Net::HTTP internal retries to prevent re-attempting reads
        # which will reuse the same timeout params and may exceed the overall
        # timeout we're aiming for. The branch that decides to retry an
        # idempotent request also catches Timeout::Error, so the wall clock
        # in #fetch would be swallowed while the status line or headers are
        # read, and the retry run with the timer already spent. Nothing is
        # lost by turning it off: the connection is never reused, so there is
        # no stale socket for a retry to recover from.
        http.max_retries = 0
      end
    end

    def perform_request(uri, address, deadline)
      http = connection_for(uri, address, deadline)
      request = Net::HTTP::Get.new(
        uri.request_uri,
        # Without an explicit Accept-Encoding, Net::HTTP negotiates gzip and
        # inflates the body itself, which would both feed attacker-chosen
        # bytes to zlib and turn the Content-Length check below into a check
        # on the compressed size. A 5 kilobyte document does not need it.
        { "Accept" => "application/json", "Accept-Encoding" => "identity" },
      )
      body = nil
      connected = false

      http.start do |connection|
        connected = true
        # Re-set this timeout later in the connection to account for the time
        # we spent trying to connect to the address.
        connection.read_timeout = [READ_TIMEOUT, remaining_until(deadline)].min
        # Net::HTTP never follows redirects on its own; a 3xx just fails
        # the status check below.
        connection.request(request) do |response|
          raise FetchError, "expected 200 OK from #{uri.hostname}, got #{response.code}" unless response.is_a?(Net::HTTPOK)

          verify_media_type!(response, uri.hostname)
          body = bounded_body(response, connection, uri.hostname, deadline)
        end
      end

      body
    rescue *TRANSPORT_ERRORS => e
      raise if connected

      raise ConnectError, "#{e.class}: #{e.message}"
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
    # out of Net::HTTP#start, which closes the connection. (The socket's own
    # budget, MAX_EXCHANGE_SIZE, would catch an oversized body too, headers
    # permitting; this check is the one that names the body.)
    def bounded_body(response, connection, host, deadline)
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

        # Shorten the timeout for the next read if we've already spent a lot of
        # time connecting and reading part of the request. Otherwise we could
        # overshoot `MAX_TOTAL_TIME` by up to `READ_TIMEOUT` seconds.
        connection.read_timeout = [connection.read_timeout, remaining_until(deadline)].min
      end

      # RFC 8259 Section 8.1: JSON exchanged between systems is UTF-8. A body
      # that is not is no document, and its bytes would otherwise travel on
      # tagged as UTF-8 — JSON.parse does not check — into every String
      # method that does: ArgumentError out of a regex, or out of the
      # base64url decoder a JWK member goes through.
      body.force_encoding(Encoding::UTF_8)
      raise FetchError, "the document from #{host} is not valid UTF-8" unless body.valid_encoding?

      # Same section: a sender must not add a byte order mark, but a reader
      # may ignore one. Editors put them on static files without asking, and
      # JSON.parse reads a leading BOM as an unexpected character, which
      # would refuse an otherwise well-formed document over a byte its author
      # never typed.
      body.delete_prefix(BYTE_ORDER_MARK)
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def remaining_until(deadline)
      [deadline - monotonic_now, 0].max
    end
  end
end
