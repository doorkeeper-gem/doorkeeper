require 'spec_helper_integration'

feature 'Private API' do
  background do
    @client   = Factory(:application)
    @resource = User.create!(:name => "Joe", :password => "sekret")
    @token    = client_is_authorized(@client, @resource)
  end

  scenario 'client requests protected resource with valid token' do
    with_access_token_header @token.token
    visit '/full_protected_resources'
    page.body.should have_content("index")
  end

  scenario 'client attempts to request protected resource with invalid token' do
    with_access_token_header "invalid"
    visit '/full_protected_resources'
    response_status_should_be 401
  end

  scenario 'client attempts to request protected resource with expired token' do
    @token.update_attribute :expires_in, -100 # expires token
    with_access_token_header @token.token
    visit '/full_protected_resources'
    response_status_should_be 401
  end

  scenario 'access token with no scopes' do
    scope_exists :admin, :description => "admin"
    @token.update_attribute :scopes, nil
    with_access_token_header @token.token
    visit '/full_protected_resources/1.json'
    response_status_should_be 401
  end
end
