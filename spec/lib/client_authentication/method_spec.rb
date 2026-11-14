# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication::Method do
  subject(:method) { described_class.new(name, client_authentication_method) }

  let(:name) { "secret_handshake" }
  let(:client_authentication_method) { double }

  it "reflects the given name" do
    expect(method.name).to eq name
  end

  it "reflects the given strategy" do
    expect(method.strategy).to eq client_authentication_method
  end

  it "does not shadow Object#method" do
    expect(method.method(:authenticate)).to be_a(::Method)
  end

  it "delegates matches_request? to the method" do
    expect(client_authentication_method).to receive(:matches_request?).with(example: true)

    method.matches_request?(example: true)
  end

  it "delegates authenticate to the method" do
    expect(client_authentication_method).to receive(:authenticate).with(example: true)

    method.authenticate(example: true)
  end

  describe "#uses_shared_secret?" do
    it "trusts a strategy that declares it" do
      declared = described_class.new(:client_secret_sounding, double(uses_shared_secret?: false))

      expect(declared.uses_shared_secret?).to be false
    end

    it "falls back to the registration name when undeclared" do
      expect(described_class.new(:my_client_secret_thing, double).uses_shared_secret?).to be true
      expect(described_class.new(:tls_client_auth, double).uses_shared_secret?).to be false
    end
  end

  describe "#auth_signing_alg_values" do
    it "answers what the strategy declares, as Strings" do
      declared = described_class.new(:client_secret_jwt, double(auth_signing_alg_values: %i[HS256 HS512]))

      expect(declared.auth_signing_alg_values).to eq(%w[HS256 HS512])
    end

    it "answers nil for a strategy that declares none" do
      expect(described_class.new(:client_secret_jwt, double(auth_signing_alg_values: [])).auth_signing_alg_values).to be_nil
      expect(described_class.new(:client_secret_jwt, double(auth_signing_alg_values: nil)).auth_signing_alg_values).to be_nil
    end

    it "answers nil for a strategy that does not declare them" do
      expect(method.auth_signing_alg_values).to be_nil
    end
  end
end
