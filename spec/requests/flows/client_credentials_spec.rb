require 'spec_helper'

feature 'Client Credentials Request' do
  given(:client) { FactoryGirl.create :application }

  context 'a valid request' do
    scenario 'authorizes the client and returns the token response' do
      headers = authorization client.uid, client.secret
      params  = { grant_type: 'client_credentials' }

      post '/oauth/token', params, headers

      should_have_json 'access_token', Doorkeeper::AccessToken.first.token
      should_have_json_within 'expires_in', Doorkeeper.configuration.access_token_expires_in, 1
      should_not_have_json 'scope'
      should_not_have_json 'refresh_token'

      should_not_have_json 'error'
      should_not_have_json 'error_description'
    end

    context 'with scopes' do
      background do
        optional_scopes_exist :write
      end

      scenario 'adds the scope to the token an returns in the response' do
        headers = authorization client.uid, client.secret
        params  = { grant_type: 'client_credentials', scope: 'write' }

        post '/oauth/token', params, headers

        should_have_json 'access_token', Doorkeeper::AccessToken.first.token
        should_have_json 'scope', 'write'
      end
    end
  end

  context 'an invalid request' do
    scenario 'does not authorize the client and returns the error' do
      headers = {}
      params  = { grant_type: 'client_credentials' }

      post '/oauth/token', params, headers

      should_have_json 'error', 'invalid_client'
      should_have_json 'error_description', translated_error_message(:invalid_client)
      should_not_have_json 'access_token'

      expect(response.status).to eq(401)
    end
  end

  def authorization(username, password)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials username, password
    { 'HTTP_AUTHORIZATION' => credentials }
  end
end
