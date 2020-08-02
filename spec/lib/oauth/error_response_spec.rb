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

    it "has a status of unauthorized for an unauthorized_client error" do
      subject = described_class.new(name: :unauthorized_client)

      expect(subject.status).to eq(:unauthorized)
    end
  end

  describe ".from_request" do
    it "has the error from request" do
      error = described_class.from_request double(error: :some_error)
      expect(error.name).to eq(:some_error)
    end

    it "ignores state if request does not respond to state" do
      error = described_class.from_request double(error: :some_error)
      expect(error.state).to be_nil
    end

    it "has state if request responds to state" do
      error = described_class.from_request double(error: :some_error, state: :hello)
      expect(error.state).to eq(:hello)
    end
  end

  it "ignores empty error values" do
    subject = described_class.new(error: :some_error, state: nil)
    expect(subject.body).not_to have_key(:state)
  end

  describe ".body" do
    subject(:body) { described_class.new(name: :some_error, state: :some_state).body }

    describe "#body" do
      it { expect(body).to have_key(:error) }
      it { expect(body).to have_key(:error_description) }
      it { expect(body).to have_key(:state) }
    end
  end

  describe ".headers" do
    subject(:headers) { error_response.headers }

    let(:error_response) { described_class.new(name: :some_error, state: :some_state) }

    it { expect(headers).to include "WWW-Authenticate" }

    describe "WWW-Authenticate header" do
      subject(:headers) { error_response.headers["WWW-Authenticate"] }

      it { expect(headers).to include("realm=\"#{error_response.send(:realm)}\"") }
      it { expect(headers).to include("error=\"#{error_response.name}\"") }
      it { expect(headers).to include("error_description=\"#{error_response.description}\"") }
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

    it "not redirectable when error name is unauthorized_client" do
      subject = described_class.new(name: :unauthorized_client, redirect_uri: "https://example.com")

      expect(subject.redirectable?).to be false
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
