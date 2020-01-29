# frozen_string_literal: true

require "spec_helper"

describe Doorkeeper do
  describe "#authenticate" do
    let(:request) { double }

    it "calls OAuth::Token#authenticate" do
      token_strategies = Doorkeeper.config.access_token_methods

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate)
        .with(request, *token_strategies)

      Doorkeeper.authenticate(request)
    end

    it "accepts custom token strategies" do
      token_strategies = %i[first_way second_way]

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate)
        .with(request, *token_strategies)

      Doorkeeper.authenticate(request, token_strategies)
    end
  end
end
