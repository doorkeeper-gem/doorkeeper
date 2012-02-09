require 'spec_helper_integration'

feature "Refresh Token Flow" do
  before do
    Doorkeeper.configure { use_refresh_token }
    client_exists
  end

  context "issuing a refresh token" do
    before do
      authorization_code_exists :application => @client
    end

    scenario "client gets the refresh token and refreshses it" do
      post token_endpoint_url(:code => @authorization.token, :client => @client)

      token = AccessToken.first

      should_have_json 'access_token',  token.token
      should_have_json 'refresh_token', token.refresh_token

      @authorization.reload.should be_revoked

      post refresh_token_endpoint_url(:client => @client, :refresh_token => token.refresh_token)

      new_token = AccessToken.last
      should_have_json 'access_token',  new_token.token
      should_have_json 'refresh_token', new_token.refresh_token

      token.token.should_not         == new_token.token
      token.refresh_token.should_not == new_token.refresh_token
    end
  end

  context "refreshing the token" do
    before do
      @token = Factory(:access_token, :application => @client, :resource_owner_id => 1, :use_refresh_token => true)
    end

    scenario "client request a token with refresh token" do
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      should_have_json 'refresh_token', AccessToken.last.refresh_token
      @token.reload.should be_revoked
    end

    scenario "client request a token with expired access token" do
      @token.update_attribute :expires_in, -100
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      should_have_json 'refresh_token', AccessToken.last.refresh_token
      @token.reload.should be_revoked
    end

    scenario "client gets an error for invalid refresh token" do
      post refresh_token_endpoint_url(:client => @client, :refresh_token => "invalid")
      should_not_have_json 'refresh_token'
      should_have_json 'error', 'invalid_grant'
    end

    scenario "client gets an error for revoked acccess token" do
      @token.revoke
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      should_not_have_json 'refresh_token'
      should_have_json 'error', 'invalid_grant'
    end
  end
end
