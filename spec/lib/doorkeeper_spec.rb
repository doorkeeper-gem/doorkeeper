require 'spec_helper_integration'

describe Doorkeeper do
  describe 'authenticate' do
    let(:token) { double('Token') }
    let(:request) { double('ActionDispatch::Request') }
    before do
      allow(Doorkeeper::OAuth::Token).to receive(:authenticate).
        with(request, *token_strategies) { token }
    end

    context 'with specific access token strategies' do
      let(:token_strategies) { [:first_way, :second_way] }

      it 'authenticates the token from the request' do
        expect(Doorkeeper.authenticate(request, token_strategies)).to eq(token)
      end
    end

    context 'with default access token strategies' do
      let(:token_strategies) { Doorkeeper.configuration.access_token_methods }

      it 'authenticates the token from the request' do
        expect(Doorkeeper.authenticate(request)).to eq(token)
      end
    end
  end
end
