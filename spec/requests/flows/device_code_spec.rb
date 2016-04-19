require 'spec_helper_integration'

describe 'Device Code Request' do
  let(:client) { FactoryGirl.create :application }

  context 'a valid request' do
    before do
      config_is_set(:device_verification_url, 'http://www.example.com/devices')
      config_is_set(:device_polling_interval, 5)
      config_is_set(:grant_flows, ['device_code'])
    end

    it 'returns the device code response' do
      headers = {}
      params = {
        grant_type: 'device_code',
        client_id: client.uid
      }

      post '/oauth/device', params, headers

      expect(response.status).to eq(200)

      access_grant = Doorkeeper::DeviceAccessGrant.first
      should_have_json 'code', access_grant.token
      should_have_json 'user_code', access_grant.user_token
      should_have_json 'verification_url', 'http://www.example.com/devices'
      should_have_json 'expires_in', access_grant.expires_in
      should_have_json 'interval', 5
    end
  end
end
