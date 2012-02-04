require 'spec_helper_integration'

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

    should_have_header 'Pragma', 'no-cache'
    should_have_header 'Cache-Control', 'no-store'

    parsed_response.should_not have_key('error')

    parsed_response['access_token'].should  == token.token
    parsed_response['token_type'].should    == "bearer"
    parsed_response['expires_in'].should    == token.expires_in
    parsed_response['refresh_token'].should be_nil
  end

  scenario "get access token for valid grant code with basic auth header" do
    post token_endpoint_url(:code => @authorization.token, :redirect_uri => @client.redirect_uri), {} , { 'HTTP_AUTHORIZATION' => basic_auth_header_for_client(@client)}
    token = AccessToken.where(:application_id => @client.id).first
    token.should_not be_nil
    token.scopes.should == [:public]

    should_have_header 'Pragma', 'no-cache'
    should_have_header 'Cache-Control', 'no-store'

    parsed_response.should_not have_key('error')

    parsed_response['access_token'].should  == token.token
    parsed_response['token_type'].should    == "bearer"
    parsed_response['expires_in'].should    == token.expires_in
    parsed_response['refresh_token'].should be_nil
  end

  scenario "get one access token for two valid grant codes with same scopes" do
    resource_owner_id = @authorization.resource_owner_id
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    tokens = AccessToken.where(:application_id => @client.id)
    tokens.size.should be(1)
    current_token = tokens.first

    current_token.expired?.should be_false
    current_token.revoked_at.should be_nil

    new_authorization = authorization_code_exists(:client => @client, :scopes => "public")
    new_authorization.resource_owner_id = resource_owner_id
    new_authorization.save
    post token_endpoint_url(:code => new_authorization.token, :client => @client)

    tokens = AccessToken.where(:application_id => @client.id)
    tokens.size.should eq(1)
  end

  scenario "create a new access token for two valid grant codes with different scopes" do
    resource_owner_id = @authorization.resource_owner_id
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    tokens = AccessToken.where(:application_id => @client.id)
    tokens.size.should be(1)
    current_token = tokens.first

    current_token.expired?.should be_false
    current_token.revoked_at.should be_nil

    new_authorization = authorization_code_exists(:client => @client, :scopes => "write")
    new_authorization.resource_owner_id = resource_owner_id
    new_authorization.save
    post token_endpoint_url(:code => new_authorization.token, :client => @client)

    AccessToken.all(:conditions => {:application_id => @client.id}).size.should eq(2)
  end

  scenario "create a new access token for two valid grant codes with different resource owners" do
    resource_owner_id = @authorization.resource_owner_id
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    tokens = AccessToken.where(:application_id => @client.id)
    tokens.size.should be(1)
    current_token = tokens.first

    current_token.expired?.should be_false
    current_token.revoked_at.should be_nil

    new_authorization = authorization_code_exists(:client => @client, :scopes => "public")

    post token_endpoint_url(:code => new_authorization.token, :client => @client)

    AccessToken.all(:conditions => {:application_id => @client.id}).size.should eq(2)
  end

  scenario "get a new access token for a valid grant code if the first access token has expired" do
    resource_owner_id = @authorization.resource_owner_id
    post token_endpoint_url(:code => @authorization.token, :client => @client)

    tokens = AccessToken.where(:application_id => @client.id)

    tokens.size.should be(1)

    current_token = tokens.first
    current_token.created_at = Time.now - current_token.expires_in - 1.second
    current_token.save

    current_token.expired?.should be_true

    id = current_token.id
    new_authorization = authorization_code_exists(:client => @client, :scopes => "public")
    new_authorization.resource_owner_id = resource_owner_id
    new_authorization.save

    post token_endpoint_url(:code => new_authorization.token, :client => @client)
    tokens = AccessToken.where(:application_id => @client.id)

    tokens.size.should eq(2)
    AccessToken.find(id).revoked_at.should_not be_nil
  end

  scenario "get access token for valid grant code with no client information" do
    post token_endpoint_url(:code => @authorization.token, :redirect_uri => @client.redirect_uri)

    token = AccessToken.where(:application_id => @client.id).first
    token.should be_nil

    should_have_header 'Pragma', 'no-cache'
    should_have_header 'Cache-Control', 'no-store'

    parsed_response.should_not have_key('access_token')
    parsed_response['error'].should == 'invalid_client'
    parsed_response['error_description'].should == I18n.translate('doorkeeper.errors.messages.invalid_client')
  end

  scenario "get error for invalid grant code" do
    post token_endpoint_url(:code => "invalid", :client => @client)

    token = AccessToken.where(:application_id => @client.id).first
    token.should be_nil

    should_have_header 'Pragma', 'no-cache'
    should_have_header 'Cache-Control', 'no-store'

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
