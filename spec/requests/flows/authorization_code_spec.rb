require 'spec_helper_integration'

feature 'Authorization Code Flow' do
  background do
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to('/sign_in') }
    client_exists
    create_resource_owner
    sign_in
  end

  scenario 'resource owner authorizes the client' do
    visit authorization_endpoint_url(:client => @client)
    click_on "Authorize"

    access_grant_should_exists_for(@client, @resource_owner)

    i_should_be_on_client_callback(@client)

    url_should_have_param("code", AccessGrant.first.token)
    url_should_not_have_param("state")
    url_should_not_have_param("error")
  end

  scenario 'resource owner authorizes the client with state parameter set' do
    visit authorization_endpoint_url(:client => @client, :state => "return-me")
    click_on "Authorize"
    url_should_have_param("code", AccessGrant.first.token)
    url_should_have_param("state", "return-me")
  end

  scenario 'returns the same token if it is still accessible' do
    client_is_authorized(@client, @resource_owner)
    visit authorization_endpoint_url(:client => @client)

    authorization_code = AccessGrant.first.token
    post token_endpoint_url(:code => authorization_code, :client => @client)

    AccessToken.count.should be(1)

    should_have_json 'access_token', AccessToken.first.token
  end

  scenario 'revokes and return new token if it is has expired' do
    client_is_authorized(@client, @resource_owner)
    token = AccessToken.first
    token.update_attribute :expires_in, -100
    visit authorization_endpoint_url(:client => @client)

    authorization_code = AccessGrant.first.token
    post token_endpoint_url(:code => authorization_code, :client => @client)

    token.reload.should be_revoked
    AccessToken.count.should be(2)

    should_have_json 'access_token', AccessToken.last.token
  end

  scenario 'resource owner requests an access token with authorization code' do
    visit authorization_endpoint_url(:client => @client)
    click_on "Authorize"

    authorization_code = AccessGrant.first.token
    post token_endpoint_url(:code => authorization_code, :client => @client)

    access_token_should_exists_for(@client, @resource_owner)

    should_not_have_json 'error'

    should_have_json 'access_token', AccessToken.first.token
    should_have_json 'token_type',   "bearer"
    should_have_json 'expires_in',   AccessToken.first.expires_in

    should_not_have_json 'refresh_token'
  end

  context 'with scopes' do
    background do
      scope_exist :public, :default => true, :description => "Access your public data"
      scope_exist :write,  :description => "Update your data"
    end

    scenario 'resource owner authorizes the client with default scopes' do
      visit authorization_endpoint_url(:client => @client)
      click_on "Authorize"
      access_grant_should_exists_for(@client, @resource_owner)
      access_grant_should_have_scopes :public
    end

    scenario 'resource owner authorizes the client with required scopes' do
      visit authorization_endpoint_url(:client => @client, :scope => "public write")
      click_on "Authorize"
      access_grant_should_have_scopes :public, :write
    end

    scenario 'new access token matches required scopes' do
      visit authorization_endpoint_url(:client => @client, :scope => "public write")
      click_on "Authorize"

      authorization_code = AccessGrant.first.token
      post token_endpoint_url(:code => authorization_code, :client => @client)

      access_token_should_exists_for(@client, @resource_owner)
      access_token_should_have_scopes :public, :write
    end

    scenario 'returns new token if scopes have changed' do
      client_is_authorized(@client, @resource_owner, :scopes => "public write")
      visit authorization_endpoint_url(:client => @client, :scope => "public")
      click_on "Authorize"

      authorization_code = AccessGrant.first.token
      post token_endpoint_url(:code => authorization_code, :client => @client)

      AccessToken.count.should be(2)

      should_have_json 'access_token', AccessToken.last.token
    end
  end
end
