# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper::OAuth::Client do
  describe :find do
    let(:method) { double }

    it "finds the client via uid" do
      client = double
      expect(method).to receive(:call).with("uid").and_return(client)
      expect(Doorkeeper::OAuth::Client.find("uid", method))
        .to be_a(Doorkeeper::OAuth::Client)
    end

    it "returns nil if client was not found" do
      expect(method).to receive(:call).with("uid").and_return(nil)
      expect(Doorkeeper::OAuth::Client.find("uid", method)).to be_nil
    end
  end

  describe ".authenticate" do
    it "returns the authenticated client via credentials" do
      credentials = Doorkeeper::OAuth::Client::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(double)
      expect(Doorkeeper::OAuth::Client.authenticate(credentials, authenticator))
        .to be_a(Doorkeeper::OAuth::Client)
    end

    it "returns nil if client was not authenticated" do
      credentials = Doorkeeper::OAuth::Client::Credentials.new("some-uid", "some-secret")
      authenticator = double
      expect(authenticator).to receive(:call).with("some-uid", "some-secret").and_return(nil)
      expect(Doorkeeper::OAuth::Client.authenticate(credentials, authenticator)).to be_nil
    end
  end
end
