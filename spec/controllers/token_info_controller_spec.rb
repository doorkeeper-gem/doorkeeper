require 'spec_helper'

describe Doorkeeper::TokenInfoController do
  describe 'when requesting token info with valid token' do
    let(:doorkeeper_token) { FactoryBot.create(:access_token) }

    describe 'successful request' do
      it 'responds with token info' do
        get :show, params: { access_token: doorkeeper_token.token }

        expect(response.body).to eq(doorkeeper_token.to_json)
      end

      it 'responds with a 200 status' do
        get :show, params: { access_token: doorkeeper_token.token }

        expect(response.status).to eq 200
      end
    end

    describe 'invalid token response' do
      it 'responds with 401 when doorkeeper_token is not valid' do
        get :show

        expect(response.status).to eq 401
        expect(response.headers['WWW-Authenticate']).to match(/^Bearer/)
      end

      it 'responds with 401 when doorkeeper_token is invalid, expired or revoked' do
        allow(controller).to receive(:doorkeeper_token).and_return(doorkeeper_token)
        allow(doorkeeper_token).to receive(:accessible?).and_return(false)

        get :show

        expect(response.status).to eq 401
        expect(response.headers['WWW-Authenticate']).to match(/^Bearer/)
      end

      it 'responds body message for error' do
        get :show

        expect(response.body).to eq(
          Doorkeeper::OAuth::InvalidTokenResponse.new.body.to_json
        )
      end
    end
  end
end
