# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::ErrorResponse do
  describe "#status" do
    it "has a status of bad_request" do
      expect(described_class.new.status).to eq(:bad_request)
    end

    it "has a status of unauthorized for an invalid_client error" do
      subject = described_class.new(name: :invalid_client)

      expect(subject.status).to eq(:unauthorized)
    end

    it "has a status of bad_request for an unauthorized_client error" do
      subject = described_class.new(name: :unauthorized_client)

      expect(subject.status).to eq(:bad_request)
    end
  end

  describe "#raise_exception!" do
    it "raises the exception class the response was built with" do
      response = described_class.new(
        name: :invalid_request,
        exception_class: Doorkeeper::Errors::InvalidRequest,
      )

      expect { response.raise_exception! }.to raise_error(Doorkeeper::Errors::InvalidRequest)
    end

    it "raises NotImplementedError when no exception class is defined" do
      expect { described_class.new.raise_exception! }
        .to raise_error(NotImplementedError, /must define #exception_class/)
    end
  end

  describe ".from_request" do
    it "has the error from request" do
      error = described_class.from_request double(error: Doorkeeper::Errors::InvalidClient)
      expect(error.name).to eq(:invalid_client)
    end

    it "ignores state if request does not respond to state" do
      error = described_class.from_request double(error: Doorkeeper::Errors::InvalidClient)
      expect(error.state).to be_nil
    end

    it "has state if request responds to state" do
      error = described_class.from_request double(error: Doorkeeper::Errors::InvalidClient, state: :hello)
      expect(error.state).to eq(:hello)
    end

    it "supports old extensions" do
      error = described_class.from_request double(error: :invalid_client)
      expect(error.name).to eq(:invalid_client)

      expect { error.raise_exception! }.to raise_error(Doorkeeper::Errors::InvalidClient)
    end
  end

  it "ignores empty error values" do
    subject = described_class.new(error: Doorkeeper::Errors::InvalidClient, state: nil)
    expect(subject.body).not_to have_key(:state)
  end

  describe ".body" do
    subject(:body) { described_class.new(name: Doorkeeper::Errors::InvalidClient, state: :some_state).body }

    describe "#body" do
      it { expect(body).to have_key(:error) }
      it { expect(body).to have_key(:error_description) }
      it { expect(body).to have_key(:state) }
    end

    context "when an issuer is supplied for an error redirected to the client" do
      subject(:body) do
        described_class.new(
          name: :access_denied,
          state: :some_state,
          redirect_uri: "https://client.example.com/cb",
          issuer: "https://auth.example.com",
        ).body
      end

      it "includes the iss parameter" do
        expect(body).to include(iss: "https://auth.example.com")
      end
    end

    context "when no issuer is supplied" do
      it "omits the iss parameter" do
        expect(body).not_to have_key(:iss)
      end
    end

    # RFC 9207 scopes the iss parameter to authorization responses. A configured
    # issuer alone must NOT leak iss into token/introspection/protected-resource
    # error bodies, which share this class but never supply an issuer.
    context "when an issuer is configured but not supplied" do
      before { config_is_set(:issuer, "https://auth.example.com") }

      it "omits the iss parameter" do
        expect(body).not_to have_key(:iss)
      end
    end

    # RFC 9207 requires iss only on responses returned to the client. Errors
    # that are not redirected to the client - non-redirectable errors and
    # out-of-band flows, which render to the user instead - must not carry it.
    context "when an issuer is supplied for a non-redirectable error" do
      subject(:body) do
        described_class.new(
          name: :invalid_client,
          state: :some_state,
          redirect_uri: "https://client.example.com/cb",
          issuer: "https://auth.example.com",
        ).body
      end

      it "omits the iss parameter" do
        expect(body).not_to have_key(:iss)
      end
    end

    context "when an issuer is supplied for an out-of-band error" do
      subject(:body) do
        described_class.new(
          name: :access_denied,
          state: :some_state,
          redirect_uri: Doorkeeper::OAuth::NonStandard::IETF_WG_OAUTH2_OOB,
          issuer: "https://auth.example.com",
        ).body
      end

      it "omits the iss parameter" do
        expect(body).not_to have_key(:iss)
      end
    end
  end

  describe ".headers" do
    subject(:headers) { error_response.headers }

    let(:error_response) { described_class.new(name: Doorkeeper::Errors::InvalidClient, state: :some_state) }

    it { expect(headers).to include "WWW-Authenticate" }

    describe "WWW-Authenticate header" do
      subject(:headers) { error_response.headers["WWW-Authenticate"] }

      it { expect(headers).to include("realm=\"#{error_response.send(:realm)}\"") }
      it { expect(headers).to include("error=\"#{error_response.name}\"") }
      it { expect(headers).to include("error_description=\"#{error_response.description}\"") }

      context "with error description containing forbidden characters (\\ or \")" do
        it "sanitize the value per RFC 6750 Section 3.1" do
          error = double(:error, name: "backslash\\", description: "\"quotes\"")
          allow(Doorkeeper::OAuth::Error).to receive(:new).and_return(error)
          expect(headers).to include("error=\"backslash_\"")
          expect(headers).to include("error_description=\"_quotes_\"")
        end
      end
    end
  end

  describe ".redirectable?" do
    it "not redirectable when error name is invalid_redirect_uri" do
      subject = described_class.new(name: :invalid_redirect_uri, redirect_uri: "https://example.com")

      expect(subject.redirectable?).to be false
    end

    it "not redirectable when error name is invalid_client" do
      subject = described_class.new(name: :invalid_client, redirect_uri: "https://example.com")

      expect(subject.redirectable?).to be false
    end

    it "is redirectable when error name is unauthorized_client" do
      subject = described_class.new(name: :unauthorized_client, redirect_uri: "https://example.com")

      expect(subject.redirectable?).to be true
    end

    it "not redirectable when redirect_uri is oob uri" do
      subject = described_class.new(name: :other_error, redirect_uri: Doorkeeper::OAuth::NonStandard::IETF_WG_OAUTH2_OOB)

      expect(subject.redirectable?).to be false
    end

    it "is redirectable when error is not related to client or redirect_uri, and redirect_uri is not oob uri" do
      subject = described_class.new(name: :other_error, redirect_uri: "https://example.com")

      expect(subject.redirectable?).to be true
    end
  end
end
