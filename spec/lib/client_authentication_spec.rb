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
    let(:client_authentication_method) { double }

    before do
      described_class.register(name, client_authentication_method)
    end

    it "registers a new Method" do
      expect(registered_method).to be_a(Doorkeeper::ClientAuthentication::Method)
    end

    it "passes on the given name" do
      expect(registered_method.name).to eq name
    end

    it "stores the given method" do
      expect(registered_method.method).to eq client_authentication_method
    end

    it "shows a warning when trying to register an already existing method" do
      expect(::Kernel).to receive(:warn).with(/already registered/)

      described_class.register(name, client_authentication_method)
    end
  end
end
