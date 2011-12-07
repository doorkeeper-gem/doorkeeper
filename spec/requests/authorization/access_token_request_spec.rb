require "spec_helper"

feature "Access Token Request" do
  background do
    client_exists
    authorization_code_exists(:client => @client, :scopes => "public")
  end

  scenario "get access token for valid grant code" do
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    token = AccessToken.where(:application_id => @client.id).first
    token.should_not be_nil
    token.scopes.should == [:public]

    parsed_response.should_not have_key('error')

    parsed_response['access_token'].should == token.token
    parsed_response['token_type'].should   == "bearer"
  end

  scenario "get error for invalid grant code" do
    post token_endpoint_url(:code => "invalid", :client => @client)

    token = AccessToken.where(:application_id => @client.id).first
    token.should be_nil

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_grant'
  end

  scenario "get error when posting an already revoked grant code" do
    # First successfull request
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    # Second attempt with same token
    expect {
      post token_endpoint_url(:code => @authorization.token, :client => @client)
    }.to_not change { AccessToken.count }

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_grant'
  end
end
