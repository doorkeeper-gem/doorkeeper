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

    it "raises when reading the body outlives the total time budget" do
      stub_request(:get, url).to_return(status: 200, body: "x" * 512)
      # Every clock reading lands past the deadline computed before the read.
      allow(Process).to receive(:clock_gettime).and_return(0, described_class::MAX_TOTAL_TIME + 1)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /too long/)
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
      100::1
      2001:db8::1
      2002::1
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
