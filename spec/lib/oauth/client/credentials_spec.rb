# frozen_string_literal: true

require "spec_helper"

class Doorkeeper::OAuth::Client
  describe Credentials do
    let(:client_id) { "some-uid" }
    let(:client_secret) { "some-secret" }

    it "is blank when the uid in credentials is blank" do
      expect(described_class.new(nil, nil)).to be_blank
      expect(described_class.new(nil, "something")).to be_blank
      expect(described_class.new("something", nil)).to be_present
      expect(described_class.new("something", "something")).to be_present
    end

    describe ".from_request" do
      let(:request) { double.as_null_object }

      let(:method) do
        ->(_request) { %w[uid secret] }
      end

      it "accepts anything that responds to #call" do
        expect(method).to receive(:call).with(request)
        described_class.from_request request, method
      end

      it "delegates methods received as symbols to Credentials class" do
        expect(described_class).to receive(:from_params).with(request)
        described_class.from_request request, :from_params
      end

      it "stops at the first credentials found" do
        not_called_method = double
        expect(not_called_method).not_to receive(:call)
        described_class.from_request request, ->(_) {}, method, not_called_method
      end

      it "returns new Credentials" do
        credentials = described_class.from_request request, method
        expect(credentials).to be_a(described_class)
      end

      it "returns uid and secret from extractor method" do
        credentials = described_class.from_request request, method
        expect(credentials.uid).to    eq("uid")
        expect(credentials.secret).to eq("secret")
      end

      context "when the request authenticates the client more than once" do
        let(:request) do
          double(
            authorization: "Basic #{Base64.encode64("basic-uid:basic-secret")}",
            parameters: { client_id: "param-uid", client_secret: "param-secret" },
          )
        end

        it "raises MultipleClientAuthMethods (RFC 6749 §2.3)" do
          expect { described_class.from_request(request, :from_basic, :from_params) }
            .to raise_error(Doorkeeper::Errors::MultipleClientAuthMethods)
        end

        it "raises it even when both methods carry the same credentials" do
          request = double(
            authorization: "Basic #{Base64.encode64("uid:secret")}",
            parameters: { client_id: "uid", client_secret: "secret" },
          )

          expect { described_class.from_request(request, :from_basic, :from_params) }
            .to raise_error(Doorkeeper::Errors::MultipleClientAuthMethods)
        end

        it "does not raise when a callable extractor is configured" do
          expect(described_class.from_request(request, :from_basic, method).uid).to eq("basic-uid")
        end
      end

      context "when the request presents more than one client identity" do
        it "raises when a bare client_id names another client than the Basic header" do
          request = double(
            authorization: "Basic #{Base64.encode64("basic-uid:basic-secret")}",
            parameters: { client_id: "param-uid" },
          )

          expect { described_class.from_request(request, :from_basic, :from_params) }
            .to raise_error(Doorkeeper::Errors::MultipleClientAuthMethods)
        end

        it "raises when the Basic header carries a bare uid and the params another client" do
          request = double(
            authorization: "Basic #{Base64.encode64("basic-uid")}",
            parameters: { client_id: "param-uid", client_secret: "param-secret" },
          )

          expect { described_class.from_request(request, :from_basic, :from_params) }
            .to raise_error(Doorkeeper::Errors::MultipleClientAuthMethods)
        end
      end

      context "when only one of the methods authenticates the client" do
        it "returns the credentials of a client that also identifies itself in the params" do
          request = double(
            authorization: "Basic #{Base64.encode64("uid:basic-secret")}",
            parameters: { client_id: "uid" },
          )

          credentials = described_class.from_request(request, :from_basic, :from_params)

          expect(credentials.uid).to    eq("uid")
          expect(credentials.secret).to eq("basic-secret")
        end

        it "ignores a blank client_id in the params (RFC 6749 §3.1: sent without a value == omitted)" do
          request = double(
            authorization: "Basic #{Base64.encode64("uid:basic-secret")}",
            parameters: { client_id: "" },
          )

          credentials = described_class.from_request(request, :from_basic, :from_params)

          expect(credentials.uid).to    eq("uid")
          expect(credentials.secret).to eq("basic-secret")
        end

        it "returns the params credentials of a public client sending no Basic header" do
          request = double(
            authorization: nil,
            parameters: { client_id: "param-uid" },
          )

          expect(described_class.from_request(request, :from_basic, :from_params).uid).to eq("param-uid")
        end
      end
    end

    describe ".from_params" do
      it "returns credentials from parameters when Authorization header is not available" do
        request = double parameters: { client_id: client_id, client_secret: client_secret }
        uid, secret = described_class.from_params(request)

        expect(uid).to eq("some-uid")
        expect(secret).to eq("some-secret")
      end

      it "is blank when there are no credentials" do
        request = double parameters: {}
        uid, secret = described_class.from_params(request)

        expect(uid).to be_blank
        expect(secret).to be_blank
      end
    end

    describe ".from_basic" do
      let(:credentials) { Base64.encode64("#{client_id}:#{client_secret}") }

      it "decodes the credentials" do
        request = double authorization: "Basic #{credentials}"
        uid, secret = described_class.from_basic(request)

        expect(uid).to eq("some-uid")
        expect(secret).to eq("some-secret")
      end

      it "is blank if Authorization is not Basic" do
        request = double authorization: credentials.to_s
        uid, secret = described_class.from_basic(request)

        expect(uid).to be_blank
        expect(secret).to be_blank
      end

      it "decodes credentials with lowercase 'basic' prefix" do
        request = double authorization: "basic #{credentials}"
        uid, secret = described_class.from_basic(request)

        expect(uid).to eq("some-uid")
        expect(secret).to eq("some-secret")
      end

      it "decodes credentials with mixed case 'BaSiC' prefix" do
        request = double authorization: "BaSiC #{credentials}"
        uid, secret = described_class.from_basic(request)

        expect(uid).to eq("some-uid")
        expect(secret).to eq("some-secret")
      end
    end
  end
end
