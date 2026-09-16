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

  describe "#auth_method_name" do
    it "answers the name the strategy declares, as a String whatever it declared it as" do
      expect(described_class.new(:mtls, double(auth_method_name: :tls_client_auth)).auth_method_name)
        .to eq("tls_client_auth")
    end

    it "answers nil for a strategy that declares none" do
      expect(described_class.new(:mtls, double).auth_method_name).to be_nil
    end
  end

  describe "#auth_signing_alg_values" do
    it "answers the values the strategy declares, as Strings whatever it declared them as" do
      method = described_class.new(:assertion, double(auth_signing_alg_values: %i[HS256 RS256]))

      expect(method.auth_signing_alg_values).to eq(%w[HS256 RS256])
    end

    # RFC 8414 Section 2 wants the entry only where an assertion method is
    # advertised, so a strategy with nothing to say leaves it off rather than
    # publishing an empty list.
    it "answers nil for a strategy that declares none" do
      expect(described_class.new(:mtls, double).auth_signing_alg_values).to be_nil
    end

    it "answers nil for a strategy declaring an empty list" do
      method = described_class.new(:mtls, double(auth_signing_alg_values: []))

      expect(method.auth_signing_alg_values).to be_nil
    end
  end

  describe "#uses_shared_secret?" do
    it "trusts a strategy that declares it" do
      declared = described_class.new(:client_secret_sounding, double(uses_shared_secret?: false))

      expect(declared.uses_shared_secret?).to be false
    end

    # Whatever the name suggests: the callers asking are about to admit an
    # unregistered client, so a strategy that has not said it is secret-free
    # is not.
    it "treats an undeclared strategy as secret-based" do
      expect(described_class.new(:my_client_secret_thing, double).uses_shared_secret?).to be true
      expect(described_class.new(:tls_client_auth, double).uses_shared_secret?).to be true
    end

    it "treats anything but an explicit false as secret-based" do
      expect(described_class.new(:tls_client_auth, double(uses_shared_secret?: nil)).uses_shared_secret?).to be true
      expect(described_class.new(:tls_client_auth, double(uses_shared_secret?: "no")).uses_shared_secret?).to be true
    end
  end
end
