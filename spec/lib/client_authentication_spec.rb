# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication do
  # Avoid global side effects from (un)registering methods.
  before do
    @original_methods = Doorkeeper::ClientAuthentication::Registry.registered_methods.deep_dup
  end

  after do
    Doorkeeper::ClientAuthentication::Registry.registered_methods = @original_methods
  end

  describe "#register" do
    subject(:registered_method) { described_class.get(name) }

    let(:name) { "puzzle_box" }
    let(:client_authentication_method) { double(matches_request?: false, authenticate: nil) }

    before do
      described_class.register(name, client_authentication_method)
    end

    it "registers a new Method" do
      expect(registered_method).to be_a(Doorkeeper::ClientAuthentication::Method)
    end

    it "normalizes the given name to a symbol" do
      expect(registered_method.name).to eq name.to_sym
    end

    it "stores the given method" do
      expect(registered_method.method).to eq client_authentication_method
    end

    it "shows a warning when trying to register an already existing method" do
      expect(::Kernel).to receive(:warn).with(/already registered/)

      described_class.register(name, client_authentication_method)
    end

    it "raises ArgumentError when the name is not symbolizable" do
      expect { described_class.register(nil, client_authentication_method) }
        .to raise_error(ArgumentError, /must be a Symbol or String/)
    end

    it "raises ArgumentError when the method does not implement the strategy interface" do
      expect { described_class.register(:incomplete, Object.new) }
        .to raise_error(ArgumentError, /must respond to/)
    end
  end

  describe "#get" do
    it "looks up a registered method by symbol or string" do
      expect(described_class.get(:client_secret_basic)).to be_a(Doorkeeper::ClientAuthentication::Method)
      expect(described_class.get("client_secret_basic")).to be_a(Doorkeeper::ClientAuthentication::Method)
    end

    it "returns nil for a non-symbolizable name instead of raising" do
      expect { described_class.get(nil) }.not_to raise_error
      expect(described_class.get(nil)).to be_nil
    end
  end
end
