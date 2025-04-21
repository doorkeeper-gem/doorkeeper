# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::ClientAuthentication do
  # Avoid global side effects
  before do
    @original_client_authentication_methods = Doorkeeper::ClientAuthentication::Registry.methods.deep_dup
  end

  after do
    Doorkeeper::ClientAuthentication::Registry.methods = @original_client_authentication_methods
  end

  describe "#register" do
    context "with a name and options" do
      subject(:the_registered_method) { described_class.get(name) }

      let(:name) { "puzzle_box" }
      let(:client_authentication_method) { double }

      before do
        described_class.register(
          name,
          client_authentication_method,
        )
      end

      it "creates a new Flow" do
        expect(the_registered_method).to be_a(Doorkeeper::ClientAuthentication::Method)
      end

      it "passes on the given name" do
        expect(the_registered_method.name).to eq name
      end

      it "sets the options" do
        expect(the_registered_method.method).to eq client_authentication_method
      end

      it "shows a warning when trying to register already existing method" do
        expect(::Kernel).to receive(:warn).with(/already registered/)

        described_class.register(
          name,
          client_authentication_method,
        )
      end
    end
  end
end
