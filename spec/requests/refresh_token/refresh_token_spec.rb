require "spec_helper"

feature "Refresh token" do
  before do
    Doorkeeper.configure { use_refresh_token }
    client_exists
  end

  context "issuing a refresh token" do
    before do
      authorization_code_exists(:client => @client)
    end

    scenario "client gets the refresh token and refreshses it" do
      post token_endpoint_url(:code => @authorization.token, :client => @client)
      refresh_token = parsed_response['refresh_token']
      access_token  = parsed_response['access_token']

      access_token.should_not be_nil
      refresh_token.should_not be_nil
      @authorization.reload.should be_revoked

      post refresh_token_endpoint_url(:client => @client, :refresh_token => refresh_token)
      new_access_token = parsed_response['access_token'].should_not be_nil
      new_refresh_token = parsed_response['refresh_token'].should_not be_nil

      access_token.should_not  == new_access_token
      refresh_token.should_not == new_refresh_token
    end
  end

  context "refreshing the token" do
    before do
      @token = Factory(:access_token, :application => @client, :resource_owner_id => 1, :use_refresh_token => true)
    end

    scenario "client request a token with refresh token" do
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      parsed_response['refresh_token'].should_not be_nil
      @token.reload.should be_revoked
    end

    scenario "client request a token with expired access token" do
      @token.update_attribute :expires_in, -100
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      parsed_response['refresh_token'].should_not be_nil
      @token.reload.should be_revoked
    end

    scenario "client gets an error for invalid refresh token" do
      post refresh_token_endpoint_url(:client => @client, :refresh_token => "invalid")
      parsed_response['error'].should == "invalid_grant"
      parsed_response['refresh_token'].should be_nil
    end

    scenario "client gets an error for revoked acccess token" do
      @token.revoke
      post refresh_token_endpoint_url(:client => @client, :refresh_token => @token.refresh_token)
      parsed_response['error'].should == "invalid_grant"
      parsed_response['refresh_token'].should be_nil
    end
  end
end
