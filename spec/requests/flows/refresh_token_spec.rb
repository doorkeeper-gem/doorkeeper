require 'spec_helper_integration'

feature 'Refresh Token Flow' do
  before do
    Doorkeeper.configure do
      orm DOORKEEPER_ORM
      use_refresh_token
    end
    client_exists
  end

  context 'issuing a refresh token' do
    before do
      authorization_code_exists application: @client
    end

    scenario 'client gets the refresh token and refreshses it' do
      post token_endpoint_url(code: @authorization.token, client: @client)

      token = Doorkeeper::AccessToken.first

      should_have_json 'access_token',  token.token
      should_have_json 'refresh_token', token.refresh_token

      expect(@authorization.reload).to be_revoked

      post refresh_token_endpoint_url(client: @client, refresh_token: token.refresh_token)

      new_token = Doorkeeper::AccessToken.last
      should_have_json 'access_token',  new_token.token
      should_have_json 'refresh_token', new_token.refresh_token

      expect(token.token).not_to         eq(new_token.token)
      expect(token.refresh_token).not_to eq(new_token.refresh_token)
    end
  end

  context 'refreshing the token' do
    before do
      @token = FactoryGirl.create(:access_token, application: @client, resource_owner_id: 1, use_refresh_token: true)
    end

    scenario 'client request a token with refresh token' do
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)
      should_have_json 'refresh_token', Doorkeeper::AccessToken.last.refresh_token
      expect(@token.reload).to be_revoked
    end

    scenario 'client request a token with expired access token' do
      @token.update_attribute :expires_in, -100
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)
      should_have_json 'refresh_token', Doorkeeper::AccessToken.last.refresh_token
      expect(@token.reload).to be_revoked
    end

    # TODO: verify proper error code for this (previously was invalid_grant)
    scenario 'client gets an error for invalid refresh token' do
      post refresh_token_endpoint_url(client: @client, refresh_token: 'invalid')
      should_not_have_json 'refresh_token'
      should_have_json 'error', 'invalid_request'
    end

    # TODO: verify proper error code for this (previously was invalid_grant)
    scenario 'client gets an error for revoked acccess token' do
      @token.revoke
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)
      should_not_have_json 'refresh_token'
      should_have_json 'error', 'invalid_request'
    end
  end

  context 'refreshing the token with multiple sessions (devices)' do
    before do
      # enable password auth to simulate other devices
      config_is_set(:resource_owner_from_credentials) { User.authenticate! params[:username], params[:password] }
      create_resource_owner
      @token = FactoryGirl.create(:access_token, application: @client, resource_owner_id: @resource_owner.id, use_refresh_token: true)
    end

    scenario 'client request a token after creating another token with the same user' do
      @token.update_attribute :expires_in, -100
      post password_token_endpoint_url(client: @client, resource_owner: @resource_owner)
      post refresh_token_endpoint_url(client: @client, refresh_token: @token.refresh_token)
      should_have_json 'refresh_token', Doorkeeper::AccessToken.last.refresh_token
      expect(@token.reload).to be_revoked
    end
  end
end
