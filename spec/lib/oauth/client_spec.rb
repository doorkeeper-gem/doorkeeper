# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::OAuth::Client do
  describe "::Credentials (deprecated alias)" do
    it "still resolves to Doorkeeper::ClientAuthentication::Credentials" do
      credentials = with_deprecation_warnings(enabled: false) do
        Doorkeeper::OAuth::Client::Credentials
      end

      expect(credentials).to be(Doorkeeper::ClientAuthentication::Credentials)
    end

    it "warns on access when deprecation warnings are enabled" do
      expect { with_deprecation_warnings { Doorkeeper::OAuth::Client::Credentials } }
        .to output(/Doorkeeper::OAuth::Client::Credentials is deprecated/).to_stderr
    end

    def with_deprecation_warnings(enabled: true)
      original = Warning[:deprecated]
      Warning[:deprecated] = enabled
      yield
    ensure
      Warning[:deprecated] = original
    end
  end

  describe ".find" do
    let(:method) { double }

    it "finds the client via uid" do
      client = double
      expect(method).to receive(:call).with("uid").and_return(client)
      expect(described_class.find("uid", method))
        .to be_a(described_class)
    end

    it "returns nil if client was not found" do
      expect(method).to receive(:call).with("uid").and_return(nil)
      expect(described_class.find("uid", method)).to be_nil
    end
  end

  describe ".authenticate" do
    it "returns the authenticated client via credentials" do
      credentials = Doorkeeper::ClientAuthentication::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(double)
      expect(described_class.authenticate(credentials, authenticator))
        .to be_a(described_class)
    end

    it "returns nil if client was not authenticated" do
      credentials = Doorkeeper::ClientAuthentication::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(nil)
      expect(described_class.authenticate(credentials, authenticator)).to be_nil
    end
  end
end
