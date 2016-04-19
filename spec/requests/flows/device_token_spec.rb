require 'spec_helper_integration'

describe 'Device Token Request' do
  let(:client) { FactoryGirl.create :application }

  context 'a valid request' do
    let(:device_access_grant) { FactoryGirl.create(:device_access_grant, application: client) }
    let(:headers) do
      {}
    end
    let(:params) do
      {
        grant_type: 'device_token',
        client_id: client.uid,
        client_secret: client.secret,
        code: device_access_grant.token
      }
    end

    before do
      config_is_set(:device_polling_interval, 5)
      config_is_set(:grant_flows, ['device_token'])
    end

    context 'when user has authorized application' do
      let(:user) { FactoryGirl.create(:user) }

      before do
        device_access_grant.update_attribute(:resource_owner_id, user.id)
      end

      it 'returns the access token' do
        post '/oauth/device', params, headers

        expect(response.status).to eq(200)

        access_token = Doorkeeper::AccessToken.first
        should_have_json 'access_token', access_token.token
        should_have_json 'token_type', 'bearer'
        should_have_json 'expires_in', access_token.expires_in
      end
    end

    context 'when user has not yet authorized application' do
      it 'returns an error' do
        post '/oauth/device', params, headers

        expect(response.status).to eq(401)

        should_have_json 'error', 'authorization_pending'
        should_have_json 'error_description', translated_error_message('authorization_pending')
      end
    end

    context 'when user declined to authorize application' do
      before do
        device_access_grant.destroy
      end

      it 'returns an error' do
        post '/oauth/device', params, headers

        expect(response.status).to eq(401)

        should_have_json 'error', 'authorization_declined'
        should_have_json 'error_description', translated_error_message('authorization_declined')
      end
    end

    context 'when access grant is expired' do
      before do
        device_access_grant.update_attribute(:revoked_at, Time.now)
      end

      it 'returns an error' do
        post '/oauth/device', params, headers

        expect(response.status).to eq(401)

        should_have_json 'error', 'code_expired'
        should_have_json 'error_description', translated_error_message('code_expired')
      end
    end

    context 'when client is polling too fast' do
      before do
        device_access_grant.update_attribute(:last_polled_at, 2.seconds.ago)
      end

      it 'returns an error' do
        post '/oauth/device', params, headers

        expect(response.status).to eq(401)

        should_have_json 'error', 'slow_down'
        should_have_json 'error_description', translated_error_message('slow_down')
      end
    end
  end
end
