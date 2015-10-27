require 'spec_helper'
require 'doorkeeper/grant_flow'

module Doorkeeper
  describe GrantFlow do
    describe :register do
      context "with a name and options" do
        let(:name) { "puzzle_box" }
        let(:grant_type_matches) { "tile_position" }
        let(:grant_type_strategy) { double }

        before do
          GrantFlow.register(name,
                              grant_type_matches: grant_type_matches,
                              grant_type_strategy: grant_type_strategy
                            )
        end

        subject(:the_registered_flow) { GrantFlow.get(name) }

        it "should create a new Flow" do
          expect(the_registered_flow).to be_a GrantFlow::Flow
        end

        it "should pass on the given name" do
          expect(the_registered_flow.name).to eq name
        end

        it "should set the options" do
          expect(the_registered_flow.grant_type_matches).to eq grant_type_matches
          expect(the_registered_flow.grant_type_strategy).to eq grant_type_strategy
        end
      end

      context "with an existing flow" do
        let(:existing_flow) { GrantFlow::Flow.new('light') }

        before do
          GrantFlow.register existing_flow
        end

        it "should record the existing Flow using its name" do
          expect(GrantFlow.get(existing_flow.name)).to eq existing_flow
        end
      end
    end
  end
end
