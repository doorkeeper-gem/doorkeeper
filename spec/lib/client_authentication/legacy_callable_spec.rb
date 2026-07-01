# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::LegacyCallable do
  let(:request) { double(:request) }

  describe "#matches_request?" do
    it "matches when the callable yields present credentials" do
      adapter = described_class.new(->(_request) { %w[uid secret] })

      expect(adapter.matches_request?(request)).to be true
    end

    it "matches a public client (uid present, blank secret)" do
      adapter = described_class.new(->(_request) { ["uid", nil] })

      expect(adapter.matches_request?(request)).to be true
    end

    it "does not match when the callable yields a blank uid" do
      adapter = described_class.new(->(_request) { [nil, "secret"] })

      expect(adapter.matches_request?(request)).to be false
    end

    it "does not match when the callable returns nil" do
      adapter = described_class.new(->(_request) { nil })

      expect(adapter.matches_request?(request)).to be false
    end
  end

  describe "#authenticate" do
    it "wraps the callable result in Credentials" do
      adapter = described_class.new(->(_request) { %w[uid secret] })

      credentials = adapter.authenticate(request)

      expect(credentials).to be_a(Doorkeeper::ClientAuthentication::Credentials)
      expect(credentials.uid).to eq("uid")
      expect(credentials.secret).to eq("secret")
    end

    it "passes the request through to the callable" do
      adapter = described_class.new(->(req) { [req, "secret"] })

      expect(adapter.authenticate(request).uid).to be(request)
    end
  end

  describe "invocation count" do
    it "invokes the wrapped extractor only once per request across matches_request? + authenticate" do
      calls = 0
      adapter = described_class.new(lambda do |_request|
        calls += 1
        %w[uid secret]
      end)

      adapter.matches_request?(request)
      adapter.authenticate(request)

      expect(calls).to eq(1)
    end

    it "re-invokes the extractor for a different request" do
      calls = 0
      adapter = described_class.new(lambda do |_request|
        calls += 1
        %w[uid secret]
      end)

      adapter.matches_request?(request)
      adapter.matches_request?(double(:another_request))

      expect(calls).to eq(2)
    end
  end
end
