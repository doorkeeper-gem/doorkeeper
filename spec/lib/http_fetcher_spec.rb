# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::HttpFetcher do
  subject(:fetcher) { described_class.new(resolver: resolver) }

  let(:url) { "https://client.example.com/oauth-client" }
  let(:public_address) { "93.184.216.34" }
  let(:resolver) { class_double(Resolv, getaddresses: [public_address]) }

  describe "#fetch" do
    it "returns the body of a 200 response" do
      stub_request(:get, url).to_return(status: 200, body: '{"client_id":"x"}')

      expect(fetcher.fetch(url)).to eq('{"client_id":"x"}')
    end

    # Net::HTTP formats the port into the connection address, where a value
    # too large to be a port raises TypeError — not one of the transport
    # errors #fetch converts into a FetchError. Callers validate their URLs,
    # but a jwks_uri comes from a document or a column rather than from
    # UrlValidator, so the guard belongs here too.
    it "raises rather than passing an out-of-range port to Net::HTTP" do
      expect { fetcher.fetch("https://client.example.com:99999999999999999999/app") }
        .to raise_error(described_class::FetchError, /out-of-range port/)
    end

    it "raises on a non-200 response" do
      stub_request(:get, url).to_return(status: 404, body: "not found")

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /404/)
    end

    it "raises on a 500 response" do
      stub_request(:get, url).to_return(status: 500)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /500/)
    end

    it "does not follow redirects and treats them as errors" do
      redirect_target = "https://elsewhere.example.com/metadata"
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => redirect_target })
      target_stub = stub_request(:get, redirect_target)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /302/)
      expect(target_stub).not_to have_been_requested
    end

    it "raises when the host does not resolve" do
      allow(resolver).to receive(:getaddresses).and_return([])
      request_stub = stub_request(:get, url)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /resolve/)
      expect(request_stub).not_to have_been_requested
    end

    # URI.parse("https:foo") is a URI::HTTPS with a nil host, so a hostless
    # URL can reach the fetcher despite an is_a?(URI::HTTPS) check upstream;
    # handing that nil to Resolv would raise ArgumentError, not FetchError.
    it "raises a FetchError without resolving when the URL has no host" do
      expect(resolver).not_to receive(:getaddresses)

      expect { fetcher.fetch("https:foo") }.to raise_error(described_class::FetchError, /no host/)
      expect { fetcher.fetch("https://") }.to raise_error(described_class::FetchError, /no host/)
    end

    it "raises without connecting when the host resolves to a special-use address" do
      allow(resolver).to receive(:getaddresses).and_return(["127.0.0.1"])
      request_stub = stub_request(:get, url)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /special-use/)
      expect(request_stub).not_to have_been_requested
    end

    # The other half of the SSRF guard: vetting the resolved addresses is
    # worth nothing if the connection then resolves the name again, so the
    # request is pinned to the address that was vetted (DNS rebinding).
    it "pins the connection to the vetted address" do
      stub_request(:get, url).to_return(status: 200, body: "{}")
      pinned = nil
      allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
        original.call(*args).tap do |http|
          allow(http).to receive(:ipaddr=).and_wrap_original do |setter, value|
            pinned = value
            setter.call(value)
          end
        end
      end

      fetcher.fetch(url)

      expect(pinned).to eq(public_address)
    end

    # URI#host keeps the brackets an IPv6 literal is written with, which
    # neither the resolver nor the special-use check reads as an address —
    # while UrlValidator accepts such a URL, so the two must agree.
    it "refuses an IPv6 literal that names a special-use address" do
      # The brackets never reach the resolver: with URI#host they would, and
      # "[::1]" resolves to nothing, so the URL would die as "could not
      # resolve" rather than as the loopback address it plainly is.
      allow(resolver).to receive(:getaddresses).with("::1").and_return(["::1"])
      request_stub = stub_request(:get, "https://[::1]/oauth-client")

      expect { fetcher.fetch("https://[::1]/oauth-client") }
        .to raise_error(described_class::FetchError, /special-use/)
      expect(request_stub).not_to have_been_requested
    end

    it "raises when any of several resolved addresses is special-use" do
      allow(resolver).to receive(:getaddresses).and_return([public_address, "10.0.0.5"])
      request_stub = stub_request(:get, url)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /special-use/)
      expect(request_stub).not_to have_been_requested
    end

    it "returns a body right at the size limit" do
      body = "x" * described_class::MAX_RESPONSE_SIZE
      stub_request(:get, url).to_return(status: 200, body: body)

      expect(fetcher.fetch(url).bytesize).to eq(described_class::MAX_RESPONSE_SIZE)
    end

    it "raises when the body exceeds the size limit" do
      stub_request(:get, url).to_return(status: 200, body: "x" * (described_class::MAX_RESPONSE_SIZE + 1))

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /exceeds/)
    end

    it "raises without reading the body when Content-Length declares an oversized document" do
      stub_request(:get, url).to_return(
        status: 200,
        body: "{}",
        headers: { "Content-Length" => (described_class::MAX_RESPONSE_SIZE + 1).to_s },
      )

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /over the/)
    end

    # Net::HTTP has no total-time setting of its own: read_timeout starts
    # over on every successful read, so a host answering a byte at a time —
    # in the status line and headers as much as in the body — never trips it.
    # Only a wall clock around the whole exchange bounds that.
    it "raises when the exchange outlives the total time budget" do
      stub_const("Doorkeeper::HttpFetcher::MAX_TOTAL_TIME", 0.05)
      # The ceiling interrupts the sleep, so the example costs its 0.05
      # seconds rather than the full second the stub would otherwise take.
      stub_request(:get, url).to_return do
        sleep 1
        { status: 200, body: "{}" }
      end

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /took too long/)
    end

    # Net::HTTP retries an idempotent request once by default, and the branch
    # that decides so catches Timeout::Error: the ceiling above would be
    # swallowed while the status line or headers are read, and the retry run
    # with the timer already spent. WebMock replaces #request rather than
    # #transport_request, so no stubbed exchange reaches that branch and the
    # setting is pinned directly instead.
    it "does not let Net::HTTP retry a request" do
      stub_request(:get, url).to_return(status: 200, body: "{}")
      connections = []
      allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
        original.call(*args).tap { |connection| connections << connection }
      end

      fetcher.fetch(url)

      expect(connections.map(&:max_retries)).to eq([0])
    end

    it "requests an identity encoding so that no body is ever inflated" do
      stub_request(:get, url).to_return(status: 200, body: "{}")

      fetcher.fetch(url)

      expect(
        a_request(:get, url).with(headers: { "Accept-Encoding" => "identity" }),
      ).to have_been_made
    end

    it "accepts a JSON media type carrying parameters" do
      stub_request(:get, url).to_return(
        status: 200,
        body: "{}",
        headers: { "Content-Type" => "application/json; charset=utf-8" },
      )

      expect(fetcher.fetch(url)).to eq("{}")
    end

    it "accepts an application/...+json media type" do
      stub_request(:get, url).to_return(
        status: 200,
        body: "{}",
        headers: { "Content-Type" => "application/jwk-set+json" },
      )

      expect(fetcher.fetch(url)).to eq("{}")
    end

    it "raises when the response declares a media type that is not JSON" do
      stub_request(:get, url).to_return(
        status: 200,
        body: "{}",
        headers: { "Content-Type" => "text/html" },
      )

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /not a JSON media type/)
    end

    it "wraps network errors in FetchError" do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError)
    end

    # Net::HTTPBadResponse descends from StandardError rather than from
    # Net::ProtocolError, so a host answering with a mangled status line or
    # header field would otherwise raise straight out of the endpoint.
    it "wraps a mangled HTTP response in FetchError" do
      stub_request(:get, url).to_raise(Net::HTTPBadResponse.new('wrong status line: "NOT-HTTP"'))

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /HTTPBadResponse/)
    end

    it "wraps a malformed header field in FetchError" do
      stub_request(:get, url).to_raise(Net::HTTPHeaderSyntaxError)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /HTTPHeaderSyntaxError/)
    end

    it "wraps a decompression failure in FetchError" do
      stub_request(:get, url).to_raise(Zlib::DataError)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /Zlib/)
    end

    it "wraps timeouts in FetchError" do
      stub_request(:get, url).to_timeout

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError)
    end

    # RFC 8259 Section 8.1: JSON exchanged between systems is UTF-8, and
    # JSON.parse would otherwise pass invalid bytes on, tagged as UTF-8, into
    # the first regex or base64url decoder to touch them.
    it "raises when the body is not valid UTF-8" do
      stub_request(:get, url).to_return(status: 200, body: "{\"client_id\":\"\xff\"}".b)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /not valid UTF-8/)
    end

    # Same section: a sender must not add one, but a reader may ignore it.
    # Editors write it onto static files unasked, and JSON.parse reads it as
    # an unexpected character.
    it "strips a leading byte order mark" do
      stub_request(:get, url).to_return(status: 200, body: "\uFEFF{\"client_id\":\"x\"}")

      expect(fetcher.fetch(url)).to eq('{"client_id":"x"}')
    end

    it "returns the body tagged as UTF-8" do
      stub_request(:get, url).to_return(status: 200, body: "{\"client_name\":\"caf\u00e9\"}".b)

      expect(fetcher.fetch(url).encoding).to eq(Encoding::UTF_8)
    end

    # WebMock replaces Net::HTTP#request, so nothing stubbed ever reaches the
    # socket. These examples serve a real one on the loopback interface and
    # skip TLS and address vetting (the loopback address is special-use) to
    # reach the read path under test.
    context "when reading from a real socket" do
      let(:server) { TCPServer.new("127.0.0.1", 0) }
      let(:loopback_url) { "https://localhost:#{server.addr[1]}/document" }
      let(:resolver) { class_double(Resolv, getaddresses: ["127.0.0.1"]) }

      around do |example|
        WebMock.disable_net_connect!(allow_localhost: true)
        example.run
      ensure
        WebMock.disable_net_connect!
      end

      before do
        allow(described_class).to receive(:special_use?).and_return(false)
        allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
          original.call(*args).tap { |connection| allow(connection).to receive(:use_ssl=) }
        end
      end

      after do
        @serving&.join(1)
        server.close
      end

      # Answers the one connection the fetch opens once its request headers
      # are in; the block writes the response.
      def serve
        @serving = Thread.new do
          client = server.accept
          begin
            while (line = client.gets) && line != "\r\n"; end
            yield client
          rescue IOError, SystemCallError
            # The fetcher hung up, which is the point of half of these examples.
          ensure
            client.close unless client.closed?
          end
        end
      end

      it "returns a document served with ordinary headers" do
        body = '{"client_id":"x"}'
        serve do |client|
          client.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
        end

        expect(fetcher.fetch(loopback_url)).to eq(body)
      end

      it "returns a document served in chunks" do
        serve do |client|
          client.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n11\r\n{\"client_id\":\"x\"}\r\n0\r\n\r\n")
        end

        expect(fetcher.fetch(loopback_url)).to eq('{"client_id":"x"}')
      end

      # Net::HTTP reads the status line and every header line with no limit
      # of its own, and before the response - and the body checks - exist.
      # Left to the wall clock alone, a host streaming headers would have
      # this process buffer whatever it could push in MAX_TOTAL_TIME.
      it "abandons a response whose headers never end" do
        serve do |client|
          client.write("HTTP/1.1 200 OK\r\n")
          loop { client.write("X-Filler: #{"a" * 1000}\r\n") }
        end

        expect { fetcher.fetch(loopback_url) }
          .to raise_error(described_class::FetchError, /exceeds #{described_class::MAX_EXCHANGE_SIZE} bytes, headers included/)
      end

      it "abandons a status line that never ends" do
        serve do |client|
          loop { client.write("HTTP/1.1 200 OK #{"a" * 1000}") }
        end

        expect { fetcher.fetch(loopback_url) }.to raise_error(described_class::FetchError, /headers included/)
      end

      # The size line of each chunk of a chunked body is read the same way.
      it "abandons a chunked body whose chunk-size line never ends" do
        serve do |client|
          client.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
          loop { client.write("0" * 1000) }
        end

        expect { fetcher.fetch(loopback_url) }.to raise_error(described_class::FetchError, /headers included/)
      end
    end
  end

  describe ".special_use?" do
    blocked = %w[
      0.0.0.1
      10.1.2.3
      100.64.0.1
      127.0.0.1
      127.8.8.8
      169.254.10.10
      172.16.0.1
      172.31.255.254
      192.0.0.10
      192.0.2.44
      192.88.99.1
      192.168.1.1
      198.18.0.1
      198.51.100.7
      203.0.113.9
      224.0.0.251
      240.0.0.1
      255.255.255.255
      ::
      ::1
      ::127.0.0.1
      ::10.0.0.1
      ::8.8.8.8
      ::ffff:127.0.0.1
      ::ffff:192.168.0.1
      64:ff9b::1
      64:ff9b:1::1
      64:ff9b:1:ffff::1
      100::1
      100:0:0:1::1
      2001::1
      2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff
      2001:db8::1
      2002::1
      3fff::1
      3fff:fff::1
      5f00::1
      5f00:ffff::1
      fc00::1
      fdff::1
      fe80::1
      ff02::fb
    ]

    blocked.each do |address|
      it "treats #{address} as special-use" do
        expect(described_class.special_use?(address)).to be true
      end
    end

    allowed = %w[
      8.8.8.8
      93.184.216.34
      172.15.255.255
      172.32.0.1
      198.17.255.255
      2606:2800:220:1:248:1893:25c8:1946
      64:ff9b:2::1
      4000::1
      6000::1
      ::ffff:8.8.8.8
      ::ffff:93.184.216.34
    ]

    allowed.each do |address|
      it "treats #{address} as publicly routable" do
        expect(described_class.special_use?(address)).to be false
      end
    end

    it "treats unparseable addresses as special-use" do
      expect(described_class.special_use?("not-an-ip")).to be true
    end
  end
end
