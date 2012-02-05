require 'spec_helper_integration'

feature "Access Token Request" do
  background do
    client_exists
    authorization_code_exists(:client => @client, :scopes => "public")
  end

  scenario "get access token for valid grant code with no client information" do
    post token_endpoint_url(:code => @authorization.token, :redirect_uri => @client.redirect_uri)

    token = AccessToken.where(:application_id => @client.id).first
    token.should be_nil

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_client'
    parsed_response['error_description'].should == I18n.translate('doorkeeper.errors.messages.invalid_client')
  end

  scenario "get error for invalid grant code" do
    post token_endpoint_url(:code => "invalid", :client => @client)

    token = AccessToken.where(:application_id => @client.id).first
    token.should be_nil

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_grant'
    parsed_response['error_description'].should == I18n.translate('doorkeeper.errors.messages.invalid_grant')
  end

  scenario "get error when posting an already revoked grant code" do
    # First successful request
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    # Second attempt with same token
    expect {
      post token_endpoint_url(:code => @authorization.token, :client => @client)
    }.to_not change { AccessToken.count }

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_grant'
  end
end
