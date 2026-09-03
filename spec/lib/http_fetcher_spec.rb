# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::HttpFetcher do
  subject(:fetcher) { described_class.new(resolver: resolver) }

  let(:url) { "https://client.example.com/oauth-client" }
  let(:public_address) { "93.184.216.34" }
  let(:public_v6_address) { "2606:2800:220:1:248:1893:25c8:1946" }
  let(:resolver) { class_double(Resolv, getaddresses: [public_address]) }

  def stub_connections(unreachable: [], seconds_per_attempt: 0, chunks: nil)
    now = 0
    read_timeouts = []
    allow(Process).to receive(:clock_gettime) { now }

    allow(Net::HTTP).to receive(:new).and_wrap_original do |new_method, *new_args|
      new_method.call(*new_args).tap do |http|
        allow(http).to receive(:start).and_wrap_original do |start_method, *start_args, &block|
          now += seconds_per_attempt
          raise Errno::ENETUNREACH if unreachable.include?(http.ipaddr)

          start_method.call(*start_args, &block)
        end

        record_read_timeouts(http, read_timeouts, chunks) { |elapsed| now += elapsed }
      end
    end

    read_timeouts
  end

  def record_read_timeouts(http, read_timeouts, chunks)
    allow(http).to receive(:request).and_wrap_original do |request_method, *args, &block|
      read_timeouts << http.read_timeout
      next request_method.call(*args, &block) unless chunks

      request_method.call(*args) do |response|
        allow(response).to receive(:read_body) do |&chunk|
          chunks.each do |elapsed|
            yield(elapsed)
            chunk.call("x")
            read_timeouts << http.read_timeout
          end
        end
        block.call(response)
      end
    end
  end

  describe "#fetch" do
    it "returns the body of a 200 response" do
      stub_request(:get, url).to_return(status: 200, body: '{"client_id":"x"}')

      expect(fetcher.fetch(url)).to eq('{"client_id":"x"}')
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

    it "falls back to the next resolved address when the first cannot be connected to" do
      allow(resolver).to receive(:getaddresses).and_return([public_v6_address, public_address])
      stub_connections(unreachable: [public_v6_address])
      stub_request(:get, url).to_return(status: 200, body: "{}")

      expect(fetcher.fetch(url)).to eq("{}")
    end

    it "raises when none of the resolved addresses can be connected to" do
      allow(resolver).to receive(:getaddresses).and_return([public_v6_address, public_address])
      stub_connections(unreachable: [public_v6_address, public_address])
      stub_request(:get, url)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /could not connect/)
    end

    it "does not try another address once a connection has been established" do
      allow(resolver).to receive(:getaddresses).and_return([public_v6_address, public_address])
      stub_request(:get, url).to_raise(Net::HTTPBadResponse).then.to_return(status: 200, body: "{}")

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /HTTPBadResponse/)
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "takes the time spent connecting out of the time left to read" do
      spent_connecting = 6
      read_timeouts = stub_connections(seconds_per_attempt: spent_connecting)
      stub_request(:get, url).to_return(status: 200, body: "{}")

      expect(fetcher.fetch(url)).to eq("{}")
      expect(read_timeouts).to eq([described_class::MAX_TOTAL_TIME - spent_connecting])
    end

    it "takes the time spent on an unreachable address out of the time left to read" do
      spent_per_address = 3
      allow(resolver).to receive(:getaddresses).and_return([public_v6_address, public_address])
      read_timeouts = stub_connections(
        unreachable: [public_v6_address],
        seconds_per_attempt: spent_per_address,
      )
      stub_request(:get, url).to_return(status: 200, body: "{}")

      expect(fetcher.fetch(url)).to eq("{}")
      expect(read_timeouts).to eq([described_class::MAX_TOTAL_TIME - (spent_per_address * 2)])
    end

    it "never allows a single read longer than the per-read timeout" do
      read_timeouts = stub_connections
      stub_request(:get, url).to_return(status: 200, body: "{}")

      expect(fetcher.fetch(url)).to eq("{}")
      expect(read_timeouts).to eq([described_class::READ_TIMEOUT])
    end

    it "shrinks the per-read timeout as a chunked body arrives" do
      spent_per_chunk = 3
      read_timeouts = stub_connections(chunks: [spent_per_chunk, spent_per_chunk])
      stub_request(:get, url).to_return(status: 200, body: "xx")

      expect(fetcher.fetch(url)).to eq("xx")
      expect(read_timeouts).to eq(
        [
          described_class::READ_TIMEOUT,
          described_class::READ_TIMEOUT,
          described_class::MAX_TOTAL_TIME - (spent_per_chunk * 2),
        ],
      )
    end

    it "stops trying further addresses once the total time budget is spent" do
      allow(resolver).to receive(:getaddresses).and_return([public_v6_address, public_address])
      stub_connections(unreachable: [public_v6_address])
      request_stub = stub_request(:get, url).to_return(status: 200, body: "{}")
      allow(Process).to receive(:clock_gettime).and_return(0, described_class::MAX_TOTAL_TIME + 1)

      expect { fetcher.fetch(url) }.to raise_error(described_class::FetchError, /could not connect/)
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
