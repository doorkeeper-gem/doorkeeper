require 'spec_helper_integration'

describe Doorkeeper do
  describe "#authenticate" do
    let(:request) { double }

    it "calls OAuth::Token#authenticate" do
      token_strategies = Doorkeeper.configuration.access_token_methods

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate).
        with(request, *token_strategies)

      Doorkeeper.authenticate(request)
    end

    it "accepts custom token strategies" do
      token_strategies = [:first_way, :second_way]

      expect(Doorkeeper::OAuth::Token).to receive(:authenticate).
        with(request, *token_strategies)

      Doorkeeper.authenticate(request, token_strategies)
    end
  end
end
