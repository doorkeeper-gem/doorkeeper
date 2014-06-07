require 'spec_helper_integration'

describe Doorkeeper::TokensController do
  describe 'when authorization has succeeded' do
    let :token do
      double(:token, authorize: true)
    end

    before do
      allow(controller).to receive(:token) { token }
    end

    it 'returns the authorization' do
      skip 'verify need of these specs'
      expect(token).to receive(:authorization)
      post :create
    end
  end

  describe 'when authorization has failed' do
    let :token do
      double(:token, authorize: false)
    end

    before do
      allow(controller).to receive(:token) { token }
    end

    it 'returns the error response' do
      skip 'verify need of these specs'
      allow(token).to receive(:error_response).and_return(double(to_json: [], status: :unauthorized))
      post :create
      expect(response.status).to eq 401
      expect(response.headers['WWW-Authenticate']).to match(/Bearer/)
    end
  end
end
