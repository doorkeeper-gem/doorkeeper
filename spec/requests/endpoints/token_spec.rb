require 'spec_helper_integration'

feature 'Token endpoint' do
  background do
    client_exists
    authorization_code_exists :application => @client, :scopes => "public"
  end

  scenario 'respond with correct headers' do
    post token_endpoint_url(:code => @authorization.token, :client => @client)
    should_have_header 'Pragma', 'no-cache'
    should_have_header 'Cache-Control', 'no-store'
  end

  scenario 'accepts client credentials with basic auth header' do
    post token_endpoint_url(:code => @authorization.token, :redirect_uri => @client.redirect_uri),
                            {} ,
                            { 'HTTP_AUTHORIZATION' => basic_auth_header_for_client(@client) }

    should_have_json 'access_token', Doorkeeper::AccessToken.first.token
  end

  scenario 'returns null for expires_in when a permanent token is set' do
    config_is_set(:access_token_expires_in, nil)
    post token_endpoint_url(:code => @authorization.token, :client => @client)
    should_have_json 'access_token', Doorkeeper::AccessToken.first.token
    should_have_json 'expires_in', nil
  end
end
