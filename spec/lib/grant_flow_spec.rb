# frozen_string_literal: true

require "spec_helper"

RSpec.describe Doorkeeper::GrantFlow do
  # Avoid global side effects
  before do
    @origin_grant_flows = Doorkeeper::GrantFlow::Registry.flows.deep_dup
  end

  after do
    Doorkeeper::GrantFlow::Registry.flows = @origin_grant_flows
  end

  describe "#register" do
    context "with a name and options" do
      subject(:the_registered_flow) { described_class.get(name) }

      let(:name) { "puzzle_box" }
      let(:grant_type_matches) { "tile_position" }
      let(:grant_type_strategy) { double }

      before do
        described_class.register(
          name,
          grant_type_matches: grant_type_matches,
          grant_type_strategy: grant_type_strategy,
        )
      end

      it "creates a new Flow" do
        expect(the_registered_flow).to be_a(Doorkeeper::GrantFlow::Flow)
      end

      it "passes on the given name" do
        expect(the_registered_flow.name).to eq name
      end

      it "sets the options" do
        expect(the_registered_flow.grant_type_matches).to eq grant_type_matches
        expect(the_registered_flow.grant_type_strategy).to eq grant_type_strategy
      end

      it "shows a warning when trying to register already existing flow" do
        expect(::Kernel).to receive(:warn).with(/already registered/)

        described_class.register(
          name,
          grant_type_matches: grant_type_matches,
          grant_type_strategy: grant_type_strategy,
        )
      end
    end

    context "with an existing flow" do
      let(:existing_flow) { Doorkeeper::GrantFlow::Flow.new("light") }

      before do
        described_class.register(existing_flow)
      end

      it "records the existing Flow using its name" do
        expect(described_class.get(existing_flow.name)).to eq existing_flow
      end
    end
  end

  describe "#register_alias" do
    it "allows to alias multiple grant flows" do
      described_class.register_alias("implicit_oidc", as: ["token", "id_token", "id_token token"])

      expect(described_class.aliases).to include(implicit_oidc: ["token", "id_token", "id_token token"])
    end

    it "allows to alias a single grant flow" do
      described_class.register_alias("implicit_oidc", as: :id_token)

      expect(described_class.aliases).to include(implicit_oidc: [:id_token])
    end
  end
end
