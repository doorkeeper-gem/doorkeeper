require 'spec_helper'

feature 'Authorization Code Flow' do
  background do
    config_is_set(:authenticate_resource_owner) { User.first || redirect_to('/sign_in') }
    client_exists
    create_resource_owner
    sign_in
  end

  scenario 'resource owner authorizes the client' do
    visit authorization_endpoint_url(client: @client)
    click_on 'Authorize'

    access_grant_should_exist_for(@client, @resource_owner)

    i_should_be_on_client_callback(@client)

    url_should_have_param('code', Doorkeeper::AccessGrant.first.token)
    url_should_not_have_param('state')
    url_should_not_have_param('error')
  end

  scenario 'resource owner authorizes using test url' do
    @client.redirect_uri = Doorkeeper.configuration.native_redirect_uri
    @client.save!
    visit authorization_endpoint_url(client: @client)
    click_on 'Authorize'

    access_grant_should_exist_for(@client, @resource_owner)

    url_should_have_param('code', Doorkeeper::AccessGrant.first.token)
    i_should_see 'Authorization code:'
    i_should_see Doorkeeper::AccessGrant.first.token
  end

  scenario 'resource owner authorizes the client with state parameter set' do
    visit authorization_endpoint_url(client: @client, state: 'return-me')
    click_on 'Authorize'
    url_should_have_param('code', Doorkeeper::AccessGrant.first.token)
    url_should_have_param('state', 'return-me')
    url_should_not_have_param('code_challenge_method')
  end

  scenario 'resource owner requests an access token with authorization code' do
    visit authorization_endpoint_url(client: @client)
    click_on 'Authorize'

    authorization_code = Doorkeeper::AccessGrant.first.token
    create_access_token authorization_code, @client

    access_token_should_exist_for(@client, @resource_owner)

    should_not_have_json 'error'

    should_have_json 'access_token', Doorkeeper::AccessToken.first.token
    should_have_json 'token_type', 'Bearer'
    should_have_json_within 'expires_in', Doorkeeper::AccessToken.first.expires_in, 1
  end

  scenario 'resource owner requests an access token with authorization code but without secret' do
    visit authorization_endpoint_url(client: @client)
    click_on 'Authorize'

    authorization_code = Doorkeeper::AccessGrant.first.token
    page.driver.post token_endpoint_url(code: authorization_code, client_id: @client.uid,
                                        redirect_uri: @client.redirect_uri)

    expect(Doorkeeper::AccessToken).not_to exist

    should_have_json 'error', 'invalid_client'
  end

  context 'with PKCE' do
    context 'plain' do
      let(:code_challenge) { 'a45a9fea-0676-477e-95b1-a40f72ac3cfb' }
      let(:code_verifier) { 'a45a9fea-0676-477e-95b1-a40f72ac3cfb' }

      scenario 'resource owner authorizes the client with code_challenge parameter set' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'plain')
        click_on 'Authorize'

        url_should_have_param('code', Doorkeeper::AccessGrant.first.token)
        url_should_not_have_param('code_challenge_method')
        url_should_not_have_param('code_challenge')
      end

      scenario 'mobile app requests an access token with authorization code but not pkce token' do
        visit authorization_endpoint_url(client: @client)
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client, code_verifier

        should_have_json 'error', 'invalid_grant'
      end

      scenario 'mobile app requests an access token with authorization code and plain code challenge method' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'plain')
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client, code_verifier

        access_token_should_exist_for(@client, @resource_owner)

        should_not_have_json 'error'

        should_have_json 'access_token', Doorkeeper::AccessToken.first.token
        should_have_json 'token_type', 'Bearer'
        should_have_json_within 'expires_in', Doorkeeper::AccessToken.first.expires_in, 1
      end

      scenario 'mobile app requests an access token with authorization code and code_challenge' do
        visit authorization_endpoint_url(client: @client,
                                         code_challenge: code_verifier,
                                         code_challenge_method: 'plain')
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client, code_verifier: nil

        should_not_have_json 'access_token'
        should_have_json 'error', 'invalid_grant'
      end
    end

    context 's256' do
      let(:code_challenge) { 'Oz733NtQ0rJP8b04fgZMJMwprn6Iw8sMCT_9bR1q4tA' }
      let(:code_verifier) { 'a45a9fea-0676-477e-95b1-a40f72ac3cfb' }

      scenario 'resource owner authorizes the client with code_challenge parameter set' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        url_should_have_param('code', Doorkeeper::AccessGrant.first.token)
        url_should_not_have_param('code_challenge_method')
        url_should_not_have_param('code_challenge')
      end

      scenario 'mobile app requests an access token with authorization code and S256 code challenge method' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client, code_verifier

        access_token_should_exist_for(@client, @resource_owner)

        should_not_have_json 'error'

        should_have_json 'access_token', Doorkeeper::AccessToken.first.token
        should_have_json 'token_type', 'Bearer'
        should_have_json_within 'expires_in', Doorkeeper::AccessToken.first.expires_in, 1
      end

      scenario 'mobile app requests an access token with authorization code and without code_verifier' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'
        authorization_code = current_params['code']
        create_access_token authorization_code, @client
        should_have_json 'error', 'invalid_request'
        should_not_have_json 'access_token'
      end

      scenario 'mobile app requests an access token with authorization code and without secret' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        page.driver.post token_endpoint_url(code: authorization_code, client_id: @client.uid,
                                            redirect_uri: @client.redirect_uri, code_verifier: code_verifier)
        should_have_json 'error', 'invalid_client'
        should_not_have_json 'access_token'
      end

      scenario 'mobile app requests an access token with authorization code and without secret but is marked as not confidential' do
        @client.update_attribute :confidential, false
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        page.driver.post token_endpoint_url(code: authorization_code, client_id: @client.uid,
                                            redirect_uri: @client.redirect_uri, code_verifier: code_verifier)
        should_not_have_json 'error'

        should_have_json 'access_token', Doorkeeper::AccessToken.first.token
        should_have_json 'token_type', 'Bearer'
        should_have_json_within 'expires_in', Doorkeeper::AccessToken.first.expires_in, 1
      end

      scenario 'mobile app requests an access token with authorization code but no code verifier' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client

        should_not_have_json 'access_token'
        should_have_json 'error', 'invalid_request'
      end

      scenario 'mobile app requests an access token with authorization code with wrong verifier' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        create_access_token authorization_code, @client, 'incorrect-code-verifier'

        should_not_have_json 'access_token'
        should_have_json 'error', 'invalid_grant'
      end

      scenario 'code_challenge_mehthod in token request is totally ignored' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge, code_challenge_method: 'S256')
        click_on 'Authorize'

        authorization_code = current_params['code']
        page.driver.post token_endpoint_url(code: authorization_code, client: @client, code_verifier: code_challenge,
                                            code_challenge_method: 'plain')

        should_not_have_json 'access_token'
        should_have_json 'error', 'invalid_grant'
      end

      scenario 'expects to set code_challenge_method explicitely without fallback' do
        visit authorization_endpoint_url(client: @client, code_challenge: code_challenge)
        expect(page).to have_content('The code challenge method must be plain or S256.')
      end
    end
  end

  context 'when application scopes are present and no scope is passed' do
    background do
      @client.update_attributes(scopes: 'public write read')
    end

    scenario 'access grant has no scope' do
      default_scopes_exist :admin
      visit authorization_endpoint_url(client: @client)
      click_on 'Authorize'
      access_grant_should_exist_for(@client, @resource_owner)
      grant = Doorkeeper::AccessGrant.first
      expect(grant.scopes).to be_empty
    end

    scenario 'access grant have scopes which are common in application scopees and default scopes' do
      default_scopes_exist :public, :write
      visit authorization_endpoint_url(client: @client)
      click_on 'Authorize'
      access_grant_should_exist_for(@client, @resource_owner)
      access_grant_should_have_scopes :public, :write
    end
  end

  context 'with scopes' do
    background do
      default_scopes_exist :public
      optional_scopes_exist :write
    end

    scenario 'resource owner authorizes the client with default scopes' do
      visit authorization_endpoint_url(client: @client)
      click_on 'Authorize'
      access_grant_should_exist_for(@client, @resource_owner)
      access_grant_should_have_scopes :public
    end

    scenario 'resource owner authorizes the client with required scopes' do
      visit authorization_endpoint_url(client: @client, scope: 'public write')
      click_on 'Authorize'
      access_grant_should_have_scopes :public, :write
    end

    scenario 'resource owner authorizes the client with required scopes (without defaults)' do
      visit authorization_endpoint_url(client: @client, scope: 'write')
      click_on 'Authorize'
      access_grant_should_have_scopes :write
    end

    scenario 'new access token matches required scopes' do
      visit authorization_endpoint_url(client: @client, scope: 'public write')
      click_on 'Authorize'

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      access_token_should_exist_for(@client, @resource_owner)
      access_token_should_have_scopes :public, :write
    end

    scenario 'returns new token if scopes have changed' do
      client_is_authorized(@client, @resource_owner, scopes: 'public write')
      visit authorization_endpoint_url(client: @client, scope: 'public')
      click_on 'Authorize'

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      expect(Doorkeeper::AccessToken.count).to be(2)

      should_have_json 'access_token', Doorkeeper::AccessToken.last.token
    end

    scenario 'resource owner authorizes the client with extra scopes' do
      client_is_authorized(@client, @resource_owner, scopes: 'public')
      visit authorization_endpoint_url(client: @client, scope: 'public write')
      click_on 'Authorize'

      authorization_code = Doorkeeper::AccessGrant.first.token
      create_access_token authorization_code, @client

      expect(Doorkeeper::AccessToken.count).to be(2)

      should_have_json 'access_token', Doorkeeper::AccessToken.last.token
      access_token_should_have_scopes :public, :write
    end
  end
end

describe 'Authorization Code Flow' do
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

    it 'second of simultaneous client requests get an error for revoked acccess token' do
      authorization_code = Doorkeeper::AccessGrant.first.token
      allow_any_instance_of(Doorkeeper::AccessGrant).to receive(:revoked?).and_return(false, true)

      post token_endpoint_url(code: authorization_code, client: @client)

      should_not_have_json 'access_token'
      should_have_json 'error', 'invalid_grant'
    end
  end
end
